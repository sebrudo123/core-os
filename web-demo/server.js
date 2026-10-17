/**
 * server.js — Punto de entrada para ejecución local y en Render.com.
 */
import app from './src/app.js';
import { config, publicConfig } from './src/config.js';
import { logger } from './src/logger.js';

const server = app.listen(config.port, () => {
  const cfg = publicConfig();
  logger.info(`Core OS — Modo Demo Web escuchando en http://localhost:${config.port}`);
  logger.info(`  demoMode=${cfg.demoMode}  terminal=${cfg.allowTerminal}  repo=${cfg.github.repo}`);
});

// Cierre ordenado.
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    logger.info(`recibida señal ${signal}, cerrando...`);
    server.close(() => process.exit(0));
  });
}

export default server;
