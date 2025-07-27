const { partialRatio } = require('fuzzball');

function parseEMR(rawText) {
  const fields = {
    name: 'Unknown',
    gender: 'Unknown',
    diagnosis: 'Not provided',
    prescription: 'Not provided',
    age: null
  };

  const lines = rawText.toLowerCase().split('\n');

  lines.forEach(line => {
    if (partialRatio("name", line) > 80 || partialRatio("hrushikesh", line) > 80) {
      const match = line.match(/([a-zA-Z\s]+)/i);
      if (match) fields.name = match[0].replace(/[^a-zA-Z\s]/g, '').trim();
    } else if (partialRatio("gender", line) > 80 || partialRatio("gerdes", line) > 80 || partialRatio("female", line) > 80 || partialRatio("male", line) > 80) {
      if (line.includes("female") || line.includes("fermale")) fields.gender = "Female";
      else if (line.includes("male")) fields.gender = "Male";
    } else if (partialRatio("diagnosis", line) > 70 || partialRatio("diag", line) > 70) {
      fields.diagnosis = line.split(':').pop().trim();
    } else if (partialRatio("prescription", line) > 70 || partialRatio("presoxiption", line) > 70 || partialRatio("presciption", line) > 70) {
      fields.prescription = line.split(':').pop().trim();
    } else if (line.includes("age") || line.includes("fige")) {
      const ageMatch = line.match(/\d+/);
      if (ageMatch) fields.age = parseInt(ageMatch[0]);
    }
  });

  return fields;
}