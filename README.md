🏥 MedDigitise

AI-Powered Medical Text Digitisation & EMR System

📌 Overview

MedDigitise is an AI-powered mobile application that digitizes handwritten medical prescriptions and clinical notes into structured Electronic Medical Records (EMR).
The system combines Flutter (Frontend), Node.js + Express (Backend), Python FastAPI (AI OCR Service), and MySQL (Database) to deliver a complete end-to-end medical digitisation pipeline.
It is designed for real-world clinical environments to reduce paperwork and improve record accuracy.

🚀 Key Features

📷 Handwritten Prescription Recognition
Capture image using mobile camera
OCR powered by:
Google ML Kit (initial phase)
Transformer-based TROCR model 
Extracts raw handwritten medical text

🧠 AI-Based EMR Structuring

Converts unstructured OCR text into structured EMR fields:
Patient Name
Age
Gender
Symptoms
Diagnosis
Medicines
Dosage
Notes

💾 Persistent EMR Storage

Records stored permanently in MySQL
Not temporary in-memory storage
Full retrieval and management support

🔎 Smart Search

Filter EMR records by:
Patient Name
Patient ID

🗑️ Bulk Record Deletion

Checkbox-based multi-selection
Batch delete functionality

🎨 Modern UI/UX

Structured scanner UI box
Card-based EMR display
Styled EMRForm layout
Animated splash screen (zoom effect)
Welcome screen with pulsing icon & Get Started button

🏗️ System Architecture

User (Flutter App)
        ↓
Capture Image / Voice
        ↓
OCR Engine (ML Kit / TROCR via FastAPI)
        ↓
Raw Text → Node.js Backend
        ↓
AI-Based EMR Formatting
        ↓
MySQL Database Storage
        ↓
Structured EMR Response
        ↓
Display in Flutter UI

🛠️ Tech Stack

📱 Frontend

  Flutter
  Dart

🌐 Backend

  Node.js
  Express.js

🤖 AI OCR Service

  Python
  FastAPI
  TROCR (Transformer-based OCR)

🗄️ Database

  MySQL


🎯 Problem Solved

  During high patient inflow, hospitals struggle with:
  Manual prescription handling
  Paper record management
  Difficulty in retrieving past records
  MedDigitise solves this using AI-powered handwritten text recognition and structured EMR storage.

📊 Project Status

  ✅ OCR Integrated
  ✅ AI EMR Structuring
  ✅ Backend + Database Connected
  ✅ Search & Delete Features
