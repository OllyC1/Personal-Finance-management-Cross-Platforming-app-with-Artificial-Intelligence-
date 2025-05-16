// openai-wrapper.mjs
import OpenAI from 'openai';

const createOpenAIClient = (apiKey) => {
  return new OpenAI({ apiKey });
};

export { createOpenAIClient };