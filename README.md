# Verifying Image Authenticity 

A complete end-to-end system for **securing**, **authenticating**, and **restoring images** using  
**SHA-256 hashing + LSB (Least Significant Bit) embedding**, built with:

- **Flutter (Frontend)**
- **FastAPI + Python (Backend)**

This system ensures **tamper detection**, **content verification**, and **original image recovery** with high accuracy.

---

##  Features

-  **Secure Image Embedding** using SHA-256 + LSB  
-  **Robust Image Authenticity**
-  **Original Image Restoration** (rebuilds the image using extracted LSBs)
-  **Authentic Accuracy %** returned by backend
-  **Modern Flutter UI** (image upload, preview, logs)
-  **High-performance FastAPI backend**
-  **Save Secured Images Locally**
-  **Activity Log Viewer + Clear Logs**
-  **Support for PNG, JPG, BMP, JPEG formats**
-  **One-tap Secure & Authenticate operations**

---

---

##  System Architecture / Workflow

### **1. Securing an Image**
1. User uploads an image  
2. Backend converts image → RGB → flatten  
3. Computes **SHA-256 hash** of the pixel data  
4. Converts hash → bits (256 bits)  
5. Extracts original LSBs (for restoration)  
6. Embeds hash bits into pixel LSBs  
7. Appends original LSBs as tail data  
8. Returns a **secured PNG image**

### **2. Authenticating an Image**
1. Backend extracts embedded hash bits + original LSB bits  
2. Restores the original RGB values  
3. Recomputes SHA-256 hash from the restored image  
4. Compares both hashes  
5. Returns:  
   - Authentication Status  
   - Authentication %  
   - Restored Image (Base64)

---

##  Installation

### **Backend (FastAPI + Python)**

```sh
cd BACKEND
pip install -r requirements.txt
````

### **Frontend (Flutter)**

```sh
cd FRONTEND
flutter pub get
```

---

##  How to Run the Project

### **Start Backend**

```sh
cd BACKEND
uvicorn main:app --reload
```

Backend runs on:

```
http://127.0.0.1:8000
```

### **Start Frontend**

```sh
cd FRONTEND
flutter run -d chrome
```

---

##  API Endpoints

### **1. Secure Image**

```
POST /secure?preserve=true
```

**Returns:**
PNG secured image (bytes stream)

### **2. Authenticate Image**

```
POST /authenticate?preserve=true
```

**Returns (JSON):**

```json
{
  "message": "Authenticated" | "Tampered",
  "authentication_percentage": 92.7,
  "restored_image_b64": "<base64>"
}
```

##  Author

**Jagruthi Dasarapu**
Verifying Image Authenticity – Secure Image Authentication System

---

##  License

This project is licensed under the **MIT License**.
Feel free to use, modify, and distribute it with attribution.
