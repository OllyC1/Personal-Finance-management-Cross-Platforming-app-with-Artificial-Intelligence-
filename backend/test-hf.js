require('dotenv').config();
const axios = require('axios');

const HF_API_URL = process.env.HF_API_URL || "https://api-inference.huggingface.co/models/meta-llama/Llama-3.2-1B";
const HF_API_KEY = process.env.HF_API_KEY;

const data = {
  inputs: "Hello, how are you?",
  parameters: {
    max_new_tokens: 50,
    temperature: 0.5
  }
};

const headers = { "Content-Type": "application/json" };
if (HF_API_KEY) {
  headers["Authorization"] = `Bearer ${HF_API_KEY}`;
}

axios
  .post(HF_API_URL, data, { headers })
  .then((response) => {
    console.log("Response data:", response.data);
  })
  .catch((err) => {
    console.error("Error calling Hugging Face API:", err.message);
    console.error(err.response ? err.response.data : err);
  });
