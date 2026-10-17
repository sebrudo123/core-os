/**
 * api/index.js — Entrada serverless para Vercel.
 * Vercel expone esta app como función y el rewrite de vercel.json enruta todo.
 */
import app from '../src/app.js';

export default app;
