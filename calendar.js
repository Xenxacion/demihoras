(function (root, factory) {
    const api = factory();
    if (typeof module === "object" && module.exports) module.exports = api;
    if (root) root.BRADEM_CALENDAR = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
    const DAY_MS = 24 * 60 * 60 * 1000;

    function utcDate(year, month, day) {
        return new Date(Date.UTC(year, month - 1, day));
    }

    function addDays(date, days) {
        return new Date(date.getTime() + days * DAY_MS);
    }

    function dateKey(date) {
        const day = String(date.getUTCDate()).padStart(2, "0");
        const month = String(date.getUTCMonth() + 1).padStart(2, "0");
        return `${day}/${month}/${date.getUTCFullYear()}`;
    }

    // Gregorian Easter calculation (Meeus/Jones/Butcher).
    function easterSunday(year) {
        const a = year % 19;
        const b = Math.floor(year / 100);
        const c = year % 100;
        const d = Math.floor(b / 4);
        const e = b % 4;
        const f = Math.floor((b + 8) / 25);
        const g = Math.floor((b - f + 1) / 3);
        const h = (19 * a + b - d - g + 15) % 30;
        const i = Math.floor(c / 4);
        const k = c % 4;
        const l = (32 + 2 * e + 2 * i - h - k) % 7;
        const m = Math.floor((a + 11 * h + 22 * l) / 451);
        const month = Math.floor((h + l - 7 * m + 114) / 31);
        const day = ((h + l - 7 * m + 114) % 31) + 1;
        return utcDate(year, month, day);
    }

    function daysInMonth(year, monthIndex) {
        return new Date(Date.UTC(year, monthIndex + 1, 0)).getUTCDate();
    }

    function transferByWeekday(date) {
        const weekday = date.getUTCDay();
        if (weekday === 2) return addDays(date, -1); // Tuesday -> prior Monday.
        if (weekday === 3) return addDays(date, -2); // Wednesday -> prior Monday.
        if (weekday === 4) return addDays(date, 4); // Thursday -> following Monday.
        if (weekday === 5) return addDays(date, 3); // Friday -> following Monday.
        // Saturday/Sunday transfers are set by the annual official calendar.
        return date;
    }

    function getArgentinaHolidays(year) {
        const y = Number(year);
        if (!Number.isInteger(y) || y < 1900 || y > 2200) return {};

        const holidays = {};
        const add = (date, name) => {
            const key = dateKey(date);
            holidays[key] = holidays[key] ? `${holidays[key]} / ${name}` : name;
        };

        [
            [1, 1, "Año Nuevo"],
            [3, 24, "Día Nacional de la Memoria por la Verdad y la Justicia"],
            [4, 2, "Día del Veterano y de los Caídos en la Guerra de Malvinas"],
            [5, 1, "Día del Trabajador"],
            [5, 25, "Día de la Revolución de Mayo"],
            [6, 20, "Paso a la Inmortalidad del Gral. Manuel Belgrano"],
            [7, 9, "Día de la Independencia"],
            [12, 8, "Inmaculada Concepción de María"],
            [12, 25, "Navidad"],
        ].forEach(([month, day, name]) => add(utcDate(y, month, day), name));

        const easter = easterSunday(y);
        add(addDays(easter, -48), "Carnaval" );
        add(addDays(easter, -47), "Carnaval" );
        add(addDays(easter, -2), "Viernes Santo");

        const transferable = [
            [6, 17, "Paso a la Inmortalidad del Gral. Martín Miguel de Güemes"],
            [8, 17, "Paso a la Inmortalidad del Gral. José de San Martín"],
            [10, 12, "Día del Respeto a la Diversidad Cultural"],
            [11, 20, "Día de la Soberanía Nacional"],
        ];
        transferable.forEach(([month, day, name]) =>
            add(transferByWeekday(utcDate(y, month, day)), name),
        );

        // The official calendars keep these weekend dates on their original day.
        // 2025 and 2026 are official dates; later weekend changes are set annually.
        return holidays;
    }

    return { daysInMonth, easterSunday: (year) => dateKey(easterSunday(year)), getArgentinaHolidays };
});
