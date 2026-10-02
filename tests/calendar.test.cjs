const test = require("node:test");
const assert = require("node:assert/strict");
const calendar = require("../calendar.js");

test("calcula Pascua y feriados movibles argentinos de 2025", () => {
    const holidays = calendar.getArgentinaHolidays(2025);
    assert.equal(calendar.easterSunday(2025), "20/04/2025");
    assert.equal(holidays["03/03/2025"], "Carnaval");
    assert.equal(holidays["04/03/2025"], "Carnaval");
    assert.equal(holidays["18/04/2025"], "Viernes Santo");
    assert.equal(holidays["16/06/2025"], "Paso a la Inmortalidad del Gral. Martín Miguel de Güemes");
    assert.equal(holidays["24/11/2025"], "Día de la Soberanía Nacional");
});

test("calcula feriados de 2026 y no arrastra fechas de otros años", () => {
    const holidays = calendar.getArgentinaHolidays(2026);
    assert.equal(calendar.easterSunday(2026), "05/04/2026");
    assert.equal(holidays["16/02/2026"], "Carnaval");
    assert.equal(holidays["17/02/2026"], "Carnaval");
    assert.equal(holidays["03/04/2026"], "Viernes Santo");
    assert.equal(holidays["15/06/2026"], "Paso a la Inmortalidad del Gral. Martín Miguel de Güemes");
    assert.equal(holidays["23/11/2026"], "Día de la Soberanía Nacional");
    assert.equal(holidays["16/06/2025"], undefined);
});

test("maneja años bisiestos, meses y años inválidos", () => {
    assert.equal(calendar.daysInMonth(2024, 1), 29);
    assert.equal(calendar.daysInMonth(2025, 1), 28);
    assert.deepEqual(calendar.getArgentinaHolidays("no-es-año"), {});
});
