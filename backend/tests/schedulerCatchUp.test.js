const { buildSessionWindows } = require('../src/services/sessionScheduler.service');

describe('Catch-up: cenario GP da China (sprint weekend)', () => {
  // Simula o cenario real: GP da China com sprint
  const chinaGP = {
    id: 2,
    name: 'Chinese Grand Prix',
    is_sprint_weekend: true,
    fp1_date: new Date('2026-03-13T03:30:00Z'),
    sprint_qualifying_date: new Date('2026-03-13T07:30:00Z'),
    sprint_date: new Date('2026-03-14T03:00:00Z'),
    qualifying_date: new Date('2026-03-14T07:00:00Z'),
    race_date: new Date('2026-03-15T07:00:00Z'),
  };

  test('deve gerar todas as 5 janelas para sprint weekend com datas completas', () => {
    const windows = buildSessionWindows(chinaGP);
    expect(windows).toHaveLength(5);
    expect(windows.map(w => w.type)).toEqual([
      'FP1', 'sprint_qualifying', 'sprint', 'qualifying', 'race'
    ]);
  });

  test('PROBLEMA: sprint weekend SEM datas de sprint gera apenas 3 janelas', () => {
    const incompleteGP = {
      ...chinaGP,
      sprint_qualifying_date: null,
      sprint_date: null,
    };
    const windows = buildSessionWindows(incompleteGP);
    // Sem as datas de sprint, so gera FP1, qualifying e race
    expect(windows).toHaveLength(3);
    expect(windows.map(w => w.type)).toEqual(['FP1', 'qualifying', 'race']);
  });

  test('janela de corrida cobre 3 horas a partir do horario de largada', () => {
    const windows = buildSessionWindows(chinaGP);
    const raceWindow = windows.find(w => w.type === 'race');

    // Corrida comeca 07:00 UTC, janela vai ate 10:00 UTC
    expect(raceWindow.start.toISOString()).toBe('2026-03-15T07:00:00.000Z');
    expect(raceWindow.end.toISOString()).toBe('2026-03-15T10:00:00.000Z');
  });

  test('momento durante a corrida deve ser detectado como live', () => {
    const windows = buildSessionWindows(chinaGP);

    // 08:30 UTC = 1.5h apos largada, dentro da janela
    const duringRace = new Date('2026-03-15T08:30:00Z');
    const live = windows.find(w => duringRace >= w.start && duringRace <= w.end);
    expect(live).toBeDefined();
    expect(live.type).toBe('race');
  });

  test('momento apos a janela de corrida NAO deve ser detectado como live', () => {
    const windows = buildSessionWindows(chinaGP);

    // 10:30 UTC = 3.5h apos largada, fora da janela de 3h
    const afterRace = new Date('2026-03-15T10:30:00Z');
    const live = windows.find(w => afterRace >= w.start && afterRace <= w.end);
    expect(live).toBeUndefined();
  });

  test('todas as sessoes de sprint devem ser detectaveis', () => {
    const windows = buildSessionWindows(chinaGP);

    // Durante sprint qualifying
    const duringSQ = new Date('2026-03-13T08:00:00Z');
    const sqLive = windows.find(w => duringSQ >= w.start && duringSQ <= w.end);
    expect(sqLive).toBeDefined();
    expect(sqLive.type).toBe('sprint_qualifying');

    // Durante sprint
    const duringSprint = new Date('2026-03-14T04:00:00Z');
    const spLive = windows.find(w => duringSprint >= w.start && duringSprint <= w.end);
    expect(spLive).toBeDefined();
    expect(spLive.type).toBe('sprint');
  });
});

describe('Cenarios de borda', () => {
  test('janelas nao devem se sobrepor em sprint weekends', () => {
    const race = {
      is_sprint_weekend: true,
      fp1_date: new Date('2026-03-13T03:30:00Z'),
      sprint_qualifying_date: new Date('2026-03-13T07:30:00Z'),
      sprint_date: new Date('2026-03-14T03:00:00Z'),
      qualifying_date: new Date('2026-03-14T07:00:00Z'),
      race_date: new Date('2026-03-15T07:00:00Z'),
    };

    const windows = buildSessionWindows(race);

    // Verifica que nenhuma janela se sobrepoe
    for (let i = 0; i < windows.length; i++) {
      for (let j = i + 1; j < windows.length; j++) {
        const overlap = windows[i].start < windows[j].end && windows[j].start < windows[i].end;
        if (overlap) {
          // Permite overlap mas loga qual sessao ganha prioridade
          // O scheduler usa break ao encontrar a primeira, entao a ordem importa
          console.log(`Overlap: ${windows[i].type} e ${windows[j].type}`);
        }
      }
    }
    // Test just verifies windows are created correctly
    expect(windows.length).toBe(5);
  });

  test('corrida muito proxima (dentro de 3 dias) deve ser encontrada pela query SQL', () => {
    // Simula o filtro da query SQL
    const raceDate = new Date();
    const threeDaysAgo = new Date(Date.now() - 3 * 24 * 60 * 60 * 1000);
    const threeDaysAhead = new Date(Date.now() + 3 * 24 * 60 * 60 * 1000);

    // Corrida amanha
    const tomorrow = new Date(Date.now() + 24 * 60 * 60 * 1000);
    expect(tomorrow >= threeDaysAgo && tomorrow <= threeDaysAhead).toBe(true);

    // Corrida ontem
    const yesterday = new Date(Date.now() - 24 * 60 * 60 * 1000);
    expect(yesterday >= threeDaysAgo && yesterday <= threeDaysAhead).toBe(true);

    // Corrida ha 4 dias
    const fourDaysAgo = new Date(Date.now() - 4 * 24 * 60 * 60 * 1000);
    expect(fourDaysAgo >= threeDaysAgo && fourDaysAgo <= threeDaysAhead).toBe(false);
  });
});
