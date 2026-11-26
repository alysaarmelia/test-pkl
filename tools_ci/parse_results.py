#!/usr/bin/env python3
"""Parser hasil pengujian otomatis -> rekap.json (+ salinan Excel).

Masukan  : berkas keluaran `flutter test --machine` (*.jsonl) dan JUnit XML (*.xml).
Keluaran : rekap.json dan (opsional) SALINAN Hasil_Pengujian.xlsx yang kolom Hasil-nya terisi.
Berkas Excel asli tidak pernah ditimpa. Hanya pustaka standar Python + openpyxl.

Pemetaan:
  * Tes Flutter di folder test/            -> lembar "White Box" (cocok berkas + nama fungsi uji)
  * Tes dengan ID "BB-nn" pada namanya     -> lembar "Black Box" (cocok kolom ID)
    (berlaku untuk JUnit XML maupun integration_test Flutter)
"""
import argparse
import json
import re
import shutil
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path

BB_RE = re.compile(r"\b(BB-(?:\d{1,3}|TAMBAHAN-\d{1,3}))\b", re.IGNORECASE)
MAKS_PESAN = 400


def norm(teks):
    return re.sub(r"\s+", " ", str(teks or "")).strip()


def berkas_relatif(path):
    """/.../repo/test/x_test.dart atau file:///... -> test/x_test.dart"""
    p = str(path or "").replace("\\", "/")
    p = re.sub(r"^file:/+", "/", p)
    cocok = list(re.finditer(r"(?:^|/)((?:integration_test|test)/[^?#]+)", p))
    return cocok[-1].group(1) if cocok else p


def potong(teks):
    teks = norm(teks)
    return teks if len(teks) <= MAKS_PESAN else teks[: MAKS_PESAN - 3] + "..."


# ---------------------------------------------------------------- Flutter
def parse_flutter_machine(path):
    """Mengembalikan (daftar_tes, galat_muat).
    tes: {nama, berkas, hasil: berhasil|gagal|dilewati, galat, sumber}
    galat_muat: {berkas: pesan} untuk berkas yang gagal dimuat/dikompilasi."""
    suites, tests, errors = {}, {}, defaultdict(list)
    done = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for baris in f:
            baris = baris.strip()
            if not baris or baris[0] not in "[{":
                continue
            try:
                data = json.loads(baris)
            except json.JSONDecodeError:
                continue
            for ev in data if isinstance(data, list) else [data]:
                if not isinstance(ev, dict):
                    continue
                t = ev.get("type")
                if t == "suite":
                    s = ev["suite"]
                    suites[s["id"]] = s.get("path", "")
                elif t == "testStart":
                    tt = ev["test"]
                    tests[tt["id"]] = tt
                elif t == "error":
                    errors[ev["testID"]].append(ev.get("error", ""))
                elif t == "testDone":
                    done[ev["testID"]] = ev
    hasil, galat_muat = [], {}
    for tid, tt in tests.items():
        d = done.get(tid)
        suite_path = suites.get(tt.get("suiteID"), "")
        berkas = berkas_relatif(suite_path or tt.get("url") or tt.get("root_url"))
        pesan = potong(" | ".join(errors.get(tid, [])[:2]))
        if d is None:
            # testStart tanpa testDone: proses terputus
            if not tt.get("name", "").startswith("loading "):
                hasil.append(dict(nama=norm(tt.get("name")), berkas=berkas, hasil="gagal",
                                  galat="Tes tidak selesai (proses terputus/timeout)", sumber=str(path)))
            continue
        gagal = d.get("result") in ("failure", "error")
        if d.get("hidden"):
            # tes pseudo ("loading <berkas>", setUpAll). Kegagalannya = berkas tak bisa dimuat.
            if gagal:
                galat_muat[berkas] = pesan or "Berkas uji gagal dimuat"
            continue
        if d.get("skipped"):
            status = "dilewati"
        else:
            status = "gagal" if gagal else "berhasil"
        hasil.append(dict(nama=norm(tt.get("name")), berkas=berkas, hasil=status,
                          galat=pesan if gagal else "", sumber=str(path)))
    return hasil, galat_muat


# ---------------------------------------------------------------- JUnit
def parse_junit(path):
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError:
        return []
    hasil = []
    for tc in root.iter("testcase"):
        nama = norm(tc.get("name"))
        kelas = norm(tc.get("classname"))
        gagal = tc.find("failure") is not None or tc.find("error") is not None
        lewat = tc.find("skipped") is not None
        pesan = ""
        for tag in ("failure", "error"):
            el = tc.find(tag)
            if el is not None:
                pesan = potong(el.get("message") or el.text)
                break
        hasil.append(dict(nama=nama, kelas=kelas, berkas=norm(tc.get("file")) or kelas,
                          hasil="gagal" if gagal else ("dilewati" if lewat else "berhasil"),
                          galat=pesan, sumber=str(path)))
    return hasil


# ---------------------------------------------------------------- pengumpulan
def kumpulkan(input_dir, daftar_berkas):
    paths = list(daftar_berkas or [])
    if input_dir:
        base = Path(input_dir)
        paths += sorted(list(base.rglob("*.jsonl")) + list(base.rglob("*.xml")))
    flutter, junit, muat, sumber = [], [], {}, []
    for p in paths:
        p = Path(p)
        if p.suffix == ".jsonl":
            tes, gm = parse_flutter_machine(p)
            flutter += tes
            muat.update(gm)
            sumber.append(f"{p} (flutter, {len(tes)} tes)")
        elif p.suffix == ".xml":
            tes = parse_junit(p)
            junit += tes
            sumber.append(f"{p} (junit, {len(tes)} tes)")
    return flutter, junit, muat, sumber


def gabung_status(daftar):
    """Gagal jika ada yang gagal; Berhasil jika ada yang berhasil; selain itu None."""
    if any(s == "gagal" for s, _ in daftar):
        return "Gagal", "; ".join(m for s, m in daftar if s == "gagal" and m)[:MAKS_PESAN]
    if any(s == "berhasil" for s, _ in daftar):
        return "Berhasil", ""
    return None, ""


def pisahkan(flutter, junit):
    """Bagi menjadi tes White Box (per berkas+nama) dan Black Box (per ID BB-nn)."""
    white, black, tanpa_id = [], defaultdict(list), []
    for t in flutter + junit:
        ids = {i.upper() for i in BB_RE.findall(t["nama"] + " " + t.get("kelas", ""))}
        if ids:
            for i in ids:
                # Pesan untuk kolom Hasil Aktual: nama skenario yang gagal (lebih mudah dibaca
                # daripada pesan galat mentah), lalu galat singkat.
                nama = BB_RE.sub("", t["nama"]).strip(" |:-")
                sisi = "server" if t["sumber"].endswith(".xml") else "UI"
                pesan = f'[{sisi}] {nama}' + (f' ({t["galat"][:100]})' if t["galat"] else "")
                black[i].append((t["hasil"], pesan))
        elif t["sumber"].endswith(".jsonl") and t["berkas"].startswith("test/"):
            white.append(t)
        else:
            tanpa_id.append(f'{t["berkas"]} :: {t["nama"]}')
    return white, black, tanpa_id


# ---------------------------------------------------------------- Excel
def cari_kolom(ws, header_row, *judul):
    peta = {}
    for c in ws[header_row]:
        if c.value is not None:
            peta[norm(c.value).lower()] = c.column
    return [peta.get(j.lower()) for j in judul]


def isi_excel(templat, keluar, white, black, galat_muat, timpa):
    import openpyxl

    src, dst = Path(templat).resolve(), Path(keluar).resolve()
    if src == dst:
        raise SystemExit("Menolak menimpa berkas Excel asli: --excel-out harus berbeda.")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)
    wb = openpyxl.load_workbook(dst)  # tanpa data_only: rumus dipertahankan
    info = dict(wb_terisi=0, wb_tidak_cocok=[], wb_baris_tanpa_hasil=[],
                bb_terisi=0, bb_id_tidak_ada_di_excel=[], bb_baris_tanpa_hasil=[], dilewati_sudah_terisi=0)

    # --- White Box
    ws = wb["White Box"]
    hdr = next(r for r in range(1, 15) if norm(ws.cell(r, 2).value).lower() == "berkas uji")
    c_berkas, c_nama, c_hasil, c_ket = cari_kolom(ws, hdr, "Berkas Uji", "Nama Fungsi Uji", "Hasil", "Keterangan")
    baris = {}
    for r in range(hdr + 1, ws.max_row + 1):
        if ws.cell(r, c_nama).value:
            baris[(norm(ws.cell(r, c_berkas).value), norm(ws.cell(r, c_nama).value))] = r
    per_baris = defaultdict(list)
    for t in white:
        kunci = (t["berkas"], t["nama"])
        r = baris.get(kunci)
        if r is None:  # nama diawali nama group: cocokkan akhiran
            kand = [rr for (b, n), rr in baris.items() if b == t["berkas"] and t["nama"].endswith(n)]
            r = kand[0] if len(kand) == 1 else None
        if r is None:
            info["wb_tidak_cocok"].append(f'{t["berkas"]} :: {t["nama"]}')
            continue
        per_baris[r].append((t["hasil"], t["galat"]))
    for r, daftar in per_baris.items():
        status, pesan = gabung_status(daftar)
        if status is None:
            continue
        if ws.cell(r, c_hasil).value and not timpa:
            info["dilewati_sudah_terisi"] += 1
            continue
        ws.cell(r, c_hasil).value = status
        if status == "Gagal" and pesan:
            ws.cell(r, c_ket).value = pesan
        info["wb_terisi"] += 1
    # berkas yang gagal dimuat: semua barisnya Gagal
    for berkas, pesan in galat_muat.items():
        for (b, n), r in baris.items():
            if b == berkas and r not in per_baris:
                ws.cell(r, c_hasil).value = "Gagal"
                ws.cell(r, c_ket).value = "Berkas gagal dimuat: " + pesan
                per_baris[r] = [("gagal", pesan)]
                info["wb_terisi"] += 1
    info["wb_baris_tanpa_hasil"] = [
        f"{ws.cell(r, 1).value}. {ws.cell(r, c_nama).value}" for r in baris.values() if r not in per_baris]

    # --- Black Box
    ws = wb["Black Box"]
    hdr = next(r for r in range(1, 15) if norm(ws.cell(r, 1).value).lower() == "id")
    c_id, c_akt, c_st = cari_kolom(ws, hdr, "ID", "Hasil Aktual", "Status")
    ids = {norm(ws.cell(r, c_id).value).upper(): r for r in range(hdr + 1, ws.max_row + 1)
           if ws.cell(r, c_id).value}
    for i, daftar in black.items():
        r = ids.get(i)
        if r is None:
            info["bb_id_tidak_ada_di_excel"].append(i)
            continue
        status, pesan = gabung_status(daftar)
        if status is None:
            continue
        if ws.cell(r, c_st).value and not timpa:
            info["dilewati_sudah_terisi"] += 1
            continue
        ws.cell(r, c_st).value = status
        if not ws.cell(r, c_akt).value or timpa:
            ws.cell(r, c_akt).value = ("Sesuai hasil yang diharapkan (uji otomatis)" if status == "Berhasil"
                                       else "Tidak sesuai: " + (pesan or "uji otomatis gagal"))
        info["bb_terisi"] += 1
    info["bb_baris_tanpa_hasil"] = [i for i, r in ids.items() if i not in black]

    wb.calculation.fullCalcOnLoad = True  # Excel menghitung ulang rumus Rekap saat dibuka
    wb.save(dst)
    return info


# ---------------------------------------------------------------- utama
def hitung(daftar_status):
    return dict(berhasil=sum(s == "berhasil" for s in daftar_status),
                gagal=sum(s == "gagal" for s in daftar_status),
                dilewati=sum(s == "dilewati" for s in daftar_status))


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--input", help="folder berisi hasil (dicari rekursif: *.jsonl, *.xml)")
    ap.add_argument("--file", action="append", default=[], help="berkas hasil tambahan (boleh berulang)")
    ap.add_argument("--output", default="tools_ci/out/rekap.json")
    ap.add_argument("--excel", help="templat Hasil_Pengujian.xlsx (hanya dibaca)")
    ap.add_argument("--excel-out", help="jalur SALINAN Excel yang diisi (wajib bila --excel)")
    ap.add_argument("--timpa", action="store_true", help="timpa sel Hasil yang sudah terisi")
    a = ap.parse_args(argv)

    flutter, junit, galat_muat, sumber = kumpulkan(a.input, a.file)
    white, black, tanpa_id = pisahkan(flutter, junit)

    rekap = dict(sumber=sumber, galat_muat_berkas=galat_muat, tes_tanpa_pemetaan=tanpa_id)
    rekap["white_box"] = dict(jumlah_dijalankan=len(white), **hitung([t["hasil"] for t in white]),
                              gagal_rinci=[f'{t["berkas"]} :: {t["nama"]} :: {t["galat"]}' for t in white if t["hasil"] == "gagal"])
    status_bb = {i: gabung_status(v)[0] for i, v in black.items()}
    rekap["black_box"] = dict(jumlah_id=len(black),
                              berhasil=sum(s == "Berhasil" for s in status_bb.values()),
                              gagal=sum(s == "Gagal" for s in status_bb.values()),
                              tanpa_status=sum(s is None for s in status_bb.values()),
                              gagal_rinci={i: gabung_status(v)[1] for i, v in black.items() if status_bb[i] == "Gagal"})
    if a.excel:
        if not a.excel_out:
            raise SystemExit("--excel-out wajib diisi bila memakai --excel")
        rekap["excel"] = isi_excel(a.excel, a.excel_out, white, black, galat_muat, a.timpa)
    wb_, bb_ = rekap["white_box"], rekap["black_box"]
    rekap["ringkasan"] = {
        "White Box": f'{wb_["berhasil"]} berhasil, {wb_["gagal"]} gagal, {wb_["dilewati"]} dilewati dari {wb_["jumlah_dijalankan"]} tes',
        "Black Box (ID BB-nn)": f'{bb_["berhasil"]} berhasil, {bb_["gagal"]} gagal dari {bb_["jumlah_id"]} ID',
        "Tes tanpa pemetaan": len(tanpa_id),
        "Berkas gagal dimuat": len(galat_muat),
    }
    if "excel" in rekap:
        e = rekap["excel"]
        rekap["ringkasan"]["Excel"] = (f'White Box terisi {e["wb_terisi"]}, tidak cocok {len(e["wb_tidak_cocok"])}; '
                                       f'Black Box terisi {e["bb_terisi"]}')
    out = Path(a.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(rekap, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(rekap["ringkasan"], ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
