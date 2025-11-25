from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse
from io import BytesIO
from PIL import Image
import numpy as np
import hashlib
import base64
import os

app = FastAPI(title="Secure Image Authentication Service")

HASH_BITS = 256
NUM_PIXELS = HASH_BITS  # use first 256 pixels
APPENDED_BYTES = HASH_BITS // 8  # 32 bytes
MIN_BITS = 6144  # Minimum bits required = 256 pixels * 3 channels * 8 bits
MIN_BYTES = MIN_BITS // 8  # 768 bytes


def image_bytes_to_rgb_array(img_bytes: bytes) -> (np.ndarray, str):
    bio = BytesIO(img_bytes)
    im = Image.open(bio).convert("RGB")
    arr = np.array(im, dtype=np.uint8)
    return arr, (im.format or "PNG")


def rgb_array_to_image_bytes(arr: np.ndarray, fmt: str = "PNG") -> bytes:
    im = Image.fromarray(arr.astype(np.uint8), mode="RGB")
    buf = BytesIO()
    im.save(buf, format=fmt)
    return buf.getvalue()


def pack_bits_to_bytes(bit_list):
    b = bytearray()
    for i in range(0, len(bit_list), 8):
        byte = 0
        for j in range(8):
            byte = (byte << 1) | int(bit_list[i + j])
        b.append(byte)
    return bytes(b)


def unpack_bytes_to_bits(bts, expected_bits=None):
    bits = []
    for byte in bts:
        for i in reversed(range(8)):
            bits.append((byte >> i) & 1)
    if expected_bits is not None:
        bits = bits[:expected_bits]
    return bits


@app.post("/secure")
async def secure_image(file: UploadFile = File(...)):
    data = await file.read()

    # ✅ Check minimum image size (6144 bits = 768 bytes)
    if len(data) < MIN_BYTES:
        raise HTTPException(
            status_code=400,
            detail="Image too small to secure. Must have at least 6144 bits (256 pixels)."
        )

    arr, fmt = image_bytes_to_rgb_array(data)

    # ✅ Hash raw pixel data
    digest = hashlib.sha256(arr.tobytes()).digest()
    digest_bits = unpack_bytes_to_bits(digest, HASH_BITS)

    flat = arr.reshape(-1, 3).copy()
    original_lsb_bits = []

    # Embed digest bits into LSBs of first NUM_PIXELS
    for i in range(NUM_PIXELS):
        r, g, b = map(int, flat[i])
        val = (r << 16) | (g << 8) | b
        lsb = val & 1

        original_lsb_bits.append(lsb)
        new_val = (val & ~1) | int(digest_bits[i])
        flat[i] = [(new_val >> 16) & 0xFF, (new_val >> 8) & 0xFF, new_val & 0xFF]

    new_arr = flat.reshape(arr.shape)
    new_image_bytes = rgb_array_to_image_bytes(new_arr, fmt=fmt)
    appended_bytes = pack_bits_to_bytes(original_lsb_bits)
    final_bytes = new_image_bytes + appended_bytes

    mime = f"image/{fmt.lower()}" if fmt else "image/png"
    return StreamingResponse(
        BytesIO(final_bytes),
        media_type=mime,
        headers={"Content-Disposition": f"attachment; filename=secured_{file.filename}"},
    )


@app.post("/authenticate")
async def authenticate_image(file: UploadFile = File(...)):
    data = await file.read()

    # ✅ Check minimum image size (6144 bits + appended bytes)
    if len(data) < MIN_BYTES + APPENDED_BYTES:
        raise HTTPException(
            status_code=400,
            detail="Image too small or lacks appended data. Must have at least 6144 bits (256 pixels)."
        )

    appended = data[-APPENDED_BYTES:]
    image_bytes = data[:-APPENDED_BYTES]

    try:
        arr, fmt = image_bytes_to_rgb_array(image_bytes)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid image bytes: {e}")

    flat = arr.reshape(-1, 3).copy()

    # Extract embedded bits
    embedded_bits = []
    for i in range(NUM_PIXELS):
        r, g, b = map(int, flat[i])
        val = (r << 16) | (g << 8) | b
        embedded_bits.append(val & 1)

    # Recover original LSBs (from appended data)
    original_bits = unpack_bytes_to_bits(appended, expected_bits=HASH_BITS)

    # Reconstruct original image
    for i in range(NUM_PIXELS):
        r, g, b = map(int, flat[i])
        val = (r << 16) | (g << 8) | b
        new_val = (val & ~1) | int(original_bits[i])
        flat[i] = [(new_val >> 16) & 0xFF, (new_val >> 8) & 0xFF, new_val & 0xFF]

    restored_arr = flat.reshape(arr.shape)
    restored_image_bytes = rgb_array_to_image_bytes(restored_arr, fmt=fmt)

    # ✅ Compute hash of raw pixel data
    computed_digest = hashlib.sha256(restored_arr.tobytes()).digest()
    computed_bits = unpack_bytes_to_bits(computed_digest, HASH_BITS)

    # Compare hashes
    match_count = sum(1 for a, b in zip(computed_bits, embedded_bits) if a == b)
    auth_percent = (match_count / HASH_BITS) * 100
    authentic = computed_bits == embedded_bits
    message = (
        "Image authentic (untampered)." if authentic else "Image tampered / altered."
    )

    restored_b64 = base64.b64encode(restored_image_bytes).decode("ascii")
    return JSONResponse(
        content={
            "authentic": authentic,
            "message": message,
            "authentication_percentage": round(auth_percent, 2),
            "restored_image_b64": restored_b64,
        }
    )


@app.get("/download_restored/{filename}")
async def download_restored(filename: str):
    for d in ["/tmp", os.getcwd()]:
        path = os.path.join(d, filename)
        if os.path.exists(path):
            return StreamingResponse(open(path, "rb"), media_type="application/octet-stream")
    raise HTTPException(status_code=404, detail="file not found")
