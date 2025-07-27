const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
]]]]]]]
const app = express();
const PORT = 3000;

app.use(express.json());
app.use(cors());

// ✅ MySQL connection pool
const pool = mysql.createPool({
    host: 'localhost',
    user: 'root',
    password: 'nitish@2005',
    database: 'project',
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0,
    connectTimeout: 60000,
});

// ✅ Fuzzy matching helper
function fuzzyIncludes(str, keywords) {
    return keywords.some(keyword => str.includes(keyword));
}

// ✅ Parse EMR raw text
function parseEMR(rawText) {
    const lines = rawText.split('\n');
    let patient_name = 'Unknown';
    let age = null;
    let gender = 'Unknown';
    let diagnosis = 'Not provided';
    let prescriptions = [];

    const nameKeywords = ['name', 'narme'];
    const ageKeywords = ['age'];
    const genderKeywords = ['male', 'female'];
    const diagnosisKeywords = ['diagnosis', 'diagnoris', 'diagnos', 'diagnosls'];
    const prescriptionKeywords = [
        'prescription', 'prosonption', 'posonptton', 'presciption',
        'þaesenption', 'prescmptton', 'prescoption'
    ];

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        const lower = line.toLowerCase();

        if (fuzzyIncludes(lower, nameKeywords)) {
            const nextLine = lines[i + 1]?.trim();
            if (nextLine && nextLine.length < 30) {
                patient_name = nextLine;
            }
        }

        const genderMatch = line.match(/(\d+)?\s*(male|female)/i);
        if (genderMatch) {
            if (genderMatch[1]) age = parseInt(genderMatch[1]);
            gender = genderMatch[2][0].toUpperCase() + genderMatch[2].slice(1).toLowerCase();
        } else if (fuzzyIncludes(lower, ageKeywords)) {
            const parts = line.split(/[:\-]/);
            const ageValue = parts[1]?.trim().match(/\d+/);
            age = ageValue ? parseInt(ageValue[0]) : age;
        }

        if (fuzzyIncludes(lower, diagnosisKeywords)) {
            const parts = line.split(/[:\-]/);
            diagnosis = parts[1]?.trim() || diagnosis;
        }

        if (fuzzyIncludes(lower, prescriptionKeywords)) {
            const parts = line.split(/[:;\-]/);
            const value = parts[1]?.trim();
            if (value && prescriptions.length < 1) {
                prescriptions.push(value);
            }
        }
    }

    return { patient_name, age, gender, diagnosis, prescriptions };
}

// 📥 POST: Insert EMR record
app.post('/emr', (req, res) => {
    const rawText = req.body.rawText;
    const structuredData = parseEMR(rawText);
    const currentDate = new Date().toISOString().split('T')[0]; // YYYY-MM-DD

    const insertQuery = `
        INSERT INTO emr_records 
        (patient_name, age, gender, diagnosis, prescription, raw_text, date)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    `;

    const { patient_name, age, gender, diagnosis, prescriptions } = structuredData;

    pool.query(
        insertQuery,
        [
            patient_name,
            age,
            gender,
            diagnosis,
            prescriptions[0] || null,
            rawText,
            currentDate,
        ],
        (err, result) => {
            if (err) {
                console.error('❌ Insert error:', err);
                return res.status(500).json({ message: 'Insert failed' });
            }

            const insertedId = result.insertId;
            const patientId = `PAT${String(insertedId).padStart(3, '0')}`;

            const updateQuery = `UPDATE emr_records SET patient_id = ? WHERE id = ?`;
            pool.query(updateQuery, [patientId, insertedId], (updateErr) => {
                if (updateErr) {
                    console.error('❌ Patient ID update failed:', updateErr);
                    return res.status(500).json({ message: 'Failed to update patient ID' });
                }

                console.log('✅ EMR record saved with Patient ID:', patientId);
                res.status(201).json({
                    message: 'EMR record created successfully',
                    patient_id: patientId,
                    emr: {
                        ...structuredData,
                        rawNotes: rawText,
                        date: currentDate
                    },
                });
            });
        }
    );
});

// 🚀 Start server
app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});