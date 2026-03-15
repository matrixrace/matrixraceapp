const { buildSessionWindows } = require('../src/services/sessionScheduler.service');

describe('buildSessionWindows', () => {
  const WINDOW_MS = 3 * 60 * 60 * 1000; // 3 horas

  describe('fim de semana normal', () => {
    const race = {
      is_sprint_weekend: false,
      fp1_date: new Date('2026-03-13T03:30:00Z'), // TL1 sexta
      qualifying_date: new Date('2026-03-14T07:00:00Z'), // Classificacao sabado
      race_date: new Date('2026-03-15T07:00:00Z'), // Corrida domingo
      sprint_qualifying_date: null,
      sprint_date: null,
    };

    test('deve gerar janelas para FP1, FP2 (estimado), FP3 (estimado), qualifying, race', () => {
      const windows = buildSessionWindows(race);
      const types = windows.map(w => w.type);
      expect(types).toEqual(['FP1', 'FP2', 'FP3', 'qualifying', 'race']);
    });

    test('FP1 deve comecar no horario da fp1_date', () => {
      const windows = buildSessionWindows(race);
      const fp1 = windows.find(w => w.type === 'FP1');
      expect(fp1.start).toEqual(race.fp1_date);
      expect(fp1.end).toEqual(new Date(race.fp1_date.getTime() + WINDOW_MS));
    });

    test('FP2 deve ser estimado como fp1 + 3.5h', () => {
      const windows = buildSessionWindows(race);
      const fp2 = windows.find(w => w.type === 'FP2');
      const expectedStart = new Date(race.fp1_date.getTime() + 3.5 * 3600000);
      expect(fp2.start).toEqual(expectedStart);
    });

    test('FP3 deve ser estimado como qualifying - 4h', () => {
      const windows = buildSessionWindows(race);
      const fp3 = windows.find(w => w.type === 'FP3');
      const expectedStart = new Date(race.qualifying_date.getTime() - 4 * 3600000);
      expect(fp3.start).toEqual(expectedStart);
    });

    test('race deve ter janela de 3h a partir de race_date', () => {
      const windows = buildSessionWindows(race);
      const raceWindow = windows.find(w => w.type === 'race');
      expect(raceWindow.start).toEqual(race.race_date);
      expect(raceWindow.end).toEqual(new Date(race.race_date.getTime() + WINDOW_MS));
    });
  });

  describe('fim de semana sprint', () => {
    const race = {
      is_sprint_weekend: true,
      fp1_date: new Date('2026-03-13T03:30:00Z'),
      sprint_qualifying_date: new Date('2026-03-13T07:30:00Z'),
      sprint_date: new Date('2026-03-14T03:00:00Z'),
      qualifying_date: new Date('2026-03-14T07:00:00Z'),
      race_date: new Date('2026-03-15T07:00:00Z'),
    };

    test('deve gerar janelas para FP1, sprint_qualifying, sprint, qualifying, race', () => {
      const windows = buildSessionWindows(race);
      const types = windows.map(w => w.type);
      expect(types).toEqual(['FP1', 'sprint_qualifying', 'sprint', 'qualifying', 'race']);
    });

    test('NAO deve gerar FP2 e FP3 para sprint weekends', () => {
      const windows = buildSessionWindows(race);
      const types = windows.map(w => w.type);
      expect(types).not.toContain('FP2');
      expect(types).not.toContain('FP3');
    });

    test('sprint_qualifying deve usar sprint_qualifying_date', () => {
      const windows = buildSessionWindows(race);
      const sq = windows.find(w => w.type === 'sprint_qualifying');
      expect(sq.start).toEqual(race.sprint_qualifying_date);
    });

    test('sprint deve usar sprint_date', () => {
      const windows = buildSessionWindows(race);
      const sp = windows.find(w => w.type === 'sprint');
      expect(sp.start).toEqual(race.sprint_date);
    });
  });

  describe('datas faltando', () => {
    test('deve pular sessoes com data null', () => {
      const race = {
        is_sprint_weekend: true,
        fp1_date: new Date('2026-03-13T03:30:00Z'),
        sprint_qualifying_date: null, // faltando!
        sprint_date: null, // faltando!
        qualifying_date: new Date('2026-03-14T07:00:00Z'),
        race_date: new Date('2026-03-15T07:00:00Z'),
      };
      const windows = buildSessionWindows(race);
      const types = windows.map(w => w.type);
      expect(types).toEqual(['FP1', 'qualifying', 'race']);
      // sprint_qualifying e sprint devem ser ignorados
      expect(types).not.toContain('sprint_qualifying');
      expect(types).not.toContain('sprint');
    });

    test('deve funcionar mesmo sem fp1_date', () => {
      const race = {
        is_sprint_weekend: false,
        fp1_date: null,
        qualifying_date: new Date('2026-03-14T07:00:00Z'),
        race_date: new Date('2026-03-15T07:00:00Z'),
      };
      const windows = buildSessionWindows(race);
      const types = windows.map(w => w.type);
      // Sem fp1, nao gera FP1 nem FP2 (que depende de fp1)
      expect(types).not.toContain('FP1');
      expect(types).not.toContain('FP2');
      // Mas FP3 (baseado em qualifying) e os demais devem existir
      expect(types).toContain('FP3');
      expect(types).toContain('qualifying');
      expect(types).toContain('race');
    });

    test('deve ignorar data invalida', () => {
      const race = {
        is_sprint_weekend: false,
        fp1_date: 'invalid-date',
        qualifying_date: null,
        race_date: new Date('2026-03-15T07:00:00Z'),
      };
      const windows = buildSessionWindows(race);
      const types = windows.map(w => w.type);
      expect(types).toEqual(['race']);
    });
  });

  describe('deteccao de sessao ao vivo', () => {
    test('deve detectar quando NOW esta dentro da janela', () => {
      const raceDate = new Date(); // agora
      raceDate.setMinutes(raceDate.getMinutes() - 30); // comecou 30 min atras

      const race = {
        is_sprint_weekend: false,
        fp1_date: null,
        qualifying_date: null,
        race_date: raceDate,
      };

      const windows = buildSessionWindows(race);
      const now = new Date();

      const live = windows.find(w => now >= w.start && now <= w.end);
      expect(live).toBeDefined();
      expect(live.type).toBe('race');
    });

    test('NAO deve detectar sessao quando NOW esta fora da janela', () => {
      const raceDate = new Date();
      raceDate.setHours(raceDate.getHours() + 5); // daqui 5 horas

      const race = {
        is_sprint_weekend: false,
        fp1_date: null,
        qualifying_date: null,
        race_date: raceDate,
      };

      const windows = buildSessionWindows(race);
      const now = new Date();

      const live = windows.find(w => now >= w.start && now <= w.end);
      expect(live).toBeUndefined();
    });

    test('NAO deve detectar sessao quando janela ja passou', () => {
      const raceDate = new Date();
      raceDate.setHours(raceDate.getHours() - 4); // 4 horas atras (janela de 3h ja passou)

      const race = {
        is_sprint_weekend: false,
        fp1_date: null,
        qualifying_date: null,
        race_date: raceDate,
      };

      const windows = buildSessionWindows(race);
      const now = new Date();

      const live = windows.find(w => now >= w.start && now <= w.end);
      expect(live).toBeUndefined();
    });
  });
});
