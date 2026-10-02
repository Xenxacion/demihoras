const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const root = path.join(__dirname, "..");
const html = fs.readFileSync(path.join(root, "index.html"), "utf8");
const sql = fs.readFileSync(path.join(root, "supabase.sql"), "utf8");

test("la página carga el calendario y mantiene los controles por año", () => {
    assert.match(html, /<script src="\.\/calendar\.js"><\/script>/);
    assert.match(html, /getArgentinaHolidays\(year\)/);
    assert.match(html, /getActiveYear\(\)/);
    assert.match(html, /id="year-select"/);
});

test("la configuración ofrece descarga e historial solo para administración", () => {
    assert.match(html, /id="backup-download"/);
    assert.match(html, /function downloadDataBackup\(\)/);
    assert.match(html, /function loadAuditHistory\(\)/);
    assert.match(html, /id="tab-cfg"/);
});

test("el SQL crea auditoría, copias, políticas y activador diario", () => {
    assert.match(sql, /create table if not exists bw_audit_log/i);
    assert.match(sql, /create table if not exists bw_backup_snapshots/i);
    assert.match(sql, /create trigger bw_solicitudes_audit/i);
    assert.match(sql, /create policy "admin select bw_audit_log"/i);
    assert.match(sql, /cron\.schedule/i);
    assert.match(sql, /to_regclass\('cron\.job'\) is not null/i);
    assert.match(sql, /current_date - interval '2 months'/i);
    assert.match(html, /2 meses/i);
});
