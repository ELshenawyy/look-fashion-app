"""
يحوّل كل صور البانر إلى نسبة 16:9 (1280×720) بـ smart center crop.

- portrait images → قصّ أفقي من المنتصف عمودياً (يحافظ على الموضوع)
- landscape images → قصّ من الجوانب أو resize مباشر
- backup → ينسخ الأصول إلى banner_originals_backup/ خارج assets/

تشغيل:
    python scripts/banner_to_landscape.py
"""

from pathlib import Path
import shutil
from PIL import Image

ROOT = Path(__file__).parent.parent
SRC = ROOT / "assets" / "banners"
BACKUP = ROOT / "banner_originals_backup"

TARGET_W, TARGET_H = 1280, 720
TARGET_RATIO = TARGET_W / TARGET_H  # 1.778
QUALITY = 88

BACKUP.mkdir(exist_ok=True)


def process(img_path: Path) -> None:
    # backup الأصل
    backup_path = BACKUP / img_path.name
    if not backup_path.exists():
        shutil.copy2(img_path, backup_path)

    img = Image.open(img_path).convert("RGB")
    w, h = img.size
    src_ratio = w / h

    if abs(src_ratio - TARGET_RATIO) < 0.01:
        # نفس النسبة تقريباً
        out = img.resize((TARGET_W, TARGET_H), Image.LANCZOS)
        mode = "resize"
    elif src_ratio > TARGET_RATIO:
        # أعرض من اللازم → قصّ من الجوانب
        new_w = int(h * TARGET_RATIO)
        left = (w - new_w) // 2
        out = img.crop((left, 0, left + new_w, h)).resize(
            (TARGET_W, TARGET_H), Image.LANCZOS
        )
        mode = "side-crop"
    else:
        # portrait → قصّ من القمة والقاع
        new_h = int(w / TARGET_RATIO)
        top = (h - new_h) // 2
        out = img.crop((0, top, w, top + new_h)).resize(
            (TARGET_W, TARGET_H), Image.LANCZOS
        )
        mode = "top-bottom-crop"

    out.save(img_path, "JPEG", quality=QUALITY, optimize=True)
    size_kb = img_path.stat().st_size // 1024
    print(f"  {img_path.name}: {w}x{h} -> 1280x720 ({mode}, {size_kb}KB)")


def main() -> None:
    print(f"Source: {SRC}")
    print(f"Backup: {BACKUP}\n")

    images = sorted(SRC.glob("banner_*.jpg"))
    if not images:
        print("ERROR: no banner_*.jpg files found")
        return

    print(f"Processing {len(images)} images:\n")
    for img_path in images:
        process(img_path)

    print(f"\nDone. Backups in: {BACKUP}")


if __name__ == "__main__":
    main()
