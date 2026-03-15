// Mock de dependencias ANTES de importar o modulo
jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

jest.mock('../src/config/database', () => ({
  pool: {
    query: jest.fn().mockResolvedValue({ rows: [] }),
  },
}));

jest.mock('../src/config/socket', () => ({
  getIo: jest.fn().mockReturnValue(null),
}));

// Mock do live.controller para evitar dependencias reais
jest.mock('../src/controllers/live.controller', () => ({
  doSessionRefresh: jest.fn(),
}));

// Usamos um timer fake para controlar setInterval
jest.useFakeTimers();

let autoRefresh;
let doSessionRefreshMock;

beforeEach(() => {
  jest.clearAllMocks();

  // Limpa o cache do modulo para reiniciar o estado
  delete require.cache[require.resolve('../src/services/autoRefresh.service')];
  autoRefresh = require('../src/services/autoRefresh.service');

  doSessionRefreshMock = require('../src/controllers/live.controller').doSessionRefresh;
});

afterEach(async () => {
  // Garante que o auto-refresh para apos cada teste
  try { await autoRefresh.stop(); } catch (e) { /* ignore */ }
});

describe('autoRefresh.service', () => {
  describe('start/stop', () => {
    test('deve iniciar com estado ativo', async () => {
      doSessionRefreshMock.mockResolvedValue({ count: 20 });
      await autoRefresh.start(1, 'race', 30000, 'scheduler');

      const status = autoRefresh.getStatus();
      expect(status.active).toBe(true);
      expect(status.raceId).toBe(1);
      expect(status.sessionType).toBe('race');
      expect(status.source).toBe('scheduler');
    });

    test('deve parar corretamente', async () => {
      doSessionRefreshMock.mockResolvedValue({ count: 20 });
      await autoRefresh.start(1, 'race', 30000, 'scheduler');
      await autoRefresh.stop();

      const status = autoRefresh.getStatus();
      expect(status.active).toBe(false);
    });

    test('isActive deve refletir o estado', async () => {
      expect(autoRefresh.isActive()).toBe(false);
      doSessionRefreshMock.mockResolvedValue({ count: 20 });
      await autoRefresh.start(1, 'race', 30000, 'scheduler');
      expect(autoRefresh.isActive()).toBe(true);
      await autoRefresh.stop();
      expect(autoRefresh.isActive()).toBe(false);
    });
  });

  describe('ciclos de refresh', () => {
    test('deve executar refresh imediatamente ao iniciar', async () => {
      doSessionRefreshMock.mockResolvedValue({ count: 20 });
      await autoRefresh.start(1, 'race', 30000, 'scheduler');

      // O primeiro refresh eh chamado imediatamente (mas eh async, vai executar na microtask queue)
      // Avanca os timers para permitir a resolucao
      await Promise.resolve();
      expect(doSessionRefreshMock).toHaveBeenCalledWith(1, 'race');
    });

    test('deve executar refresh a cada intervalo', async () => {
      doSessionRefreshMock.mockResolvedValue({ count: 20 });
      await autoRefresh.start(1, 'race', 30000, 'scheduler');

      // Reset mock para contar apenas chamadas dos intervalos
      doSessionRefreshMock.mockClear();

      // Avanca 30s
      jest.advanceTimersByTime(30000);
      await Promise.resolve();
      expect(doSessionRefreshMock).toHaveBeenCalledTimes(1);

      // Avanca mais 30s
      jest.advanceTimersByTime(30000);
      await Promise.resolve();
      expect(doSessionRefreshMock).toHaveBeenCalledTimes(2);
    });
  });

  describe('tratamento de erros', () => {
    test('erros transitorios NAO devem contar para limite de parada', async () => {
      doSessionRefreshMock
        .mockRejectedValue(new Error('A sessao pode nao ter acontecido ainda.'));

      await autoRefresh.start(1, 'race', 30000, 'scheduler');
      await Promise.resolve();

      // Simula 15 erros transitorios (mais que MAX_CONSECUTIVE_ERRORS = 10)
      for (let i = 0; i < 15; i++) {
        jest.advanceTimersByTime(30000);
        await Promise.resolve();
        await Promise.resolve(); // duplo para garantir resolucao
      }

      // Deve continuar ativo mesmo apos 15 erros transitorios
      const status = autoRefresh.getStatus();
      expect(status.active).toBe(true);
      expect(status.transientErrorCount).toBeGreaterThan(0);
      expect(status.errorCount).toBe(0);
    });

    test('erros reais devem contar para limite de parada', async () => {
      doSessionRefreshMock
        .mockRejectedValue(new Error('Piloto XYZ nao encontrado no banco'));

      await autoRefresh.start(1, 'race', 30000, 'scheduler');

      // Simula 10+ ciclos de erro real
      for (let i = 0; i < 12; i++) {
        jest.advanceTimersByTime(30000);
        await Promise.resolve();
        await Promise.resolve();
      }

      // Deve ter parado apos 10 erros reais
      const status = autoRefresh.getStatus();
      expect(status.active).toBe(false);
    });

    test('erro de timeout deve ser tratado como transitorio', async () => {
      doSessionRefreshMock
        .mockRejectedValue(new Error('Timeout ao chamar F1Dashboard API'));

      await autoRefresh.start(1, 'race', 30000, 'scheduler');

      for (let i = 0; i < 12; i++) {
        jest.advanceTimersByTime(30000);
        await Promise.resolve();
        await Promise.resolve();
      }

      // Deve continuar ativo (timeout eh transitorio)
      expect(autoRefresh.isActive()).toBe(true);
    });

    test('erro de parse deve ser tratado como transitorio', async () => {
      doSessionRefreshMock
        .mockRejectedValue(new Error('Falha ao parsear resposta da F1Dashboard API (status=502)'));

      await autoRefresh.start(1, 'race', 30000, 'scheduler');

      for (let i = 0; i < 12; i++) {
        jest.advanceTimersByTime(30000);
        await Promise.resolve();
        await Promise.resolve();
      }

      expect(autoRefresh.isActive()).toBe(true);
    });

    test('sucesso deve resetar contadores de erro', async () => {
      // Primeiro erro
      doSessionRefreshMock.mockRejectedValueOnce(new Error('Piloto XYZ nao encontrado'));
      await autoRefresh.start(1, 'race', 30000, 'scheduler');
      await Promise.resolve();

      // Depois sucesso
      doSessionRefreshMock.mockResolvedValue({ count: 20 });
      jest.advanceTimersByTime(30000);
      await Promise.resolve();
      await Promise.resolve();

      const status = autoRefresh.getStatus();
      expect(status.errorCount).toBe(0);
      expect(status.transientErrorCount).toBe(0);
      expect(status.successCount).toBeGreaterThanOrEqual(1);
    });
  });
});
