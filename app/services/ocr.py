"""Service OCR pour le scan de factures (basé sur EasyOCR, cf. projet cni-ocr).

Extrait depuis une photo de facture :
- Montant total
- Date
- Nom du commerçant
- Catégorie suggérée
"""
import re
from datetime import datetime

try:
    import numpy as np
    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False

try:
    import cv2
    HAS_CV2 = True
except ImportError:
    HAS_CV2 = False

try:
    import easyocr
    HAS_EASYOCR = True
except ImportError:
    HAS_EASYOCR = False

CATEGORY_KEYWORDS = [
    ("Alimentation", ["restaurant", "supermarche", "supermarche", "cafe", "boulangerie",
                      "marche", "alimentation", "epicerie", "boucherie", "fast"],
     "restaurant"),
    ("Transport", ["essence", "carburant", "station", "taxi", "transport", "sncf",
                   "dakar dem dikk", "petrol", "gazole"],
     "directions_car"),
    ("Logement", ["loyer", "eaux", "sde", "sonatel", "electricite", "edf", "immobilier",
                  "facture d'eau", "facture d'elec"],
     "home"),
    ("Santé", ["pharmacie", "hopital", "clinique", "medecin", "sante"],
     "local_hospital"),
    ("Shopping", ["boutique", "boutiq", "vetement", "magasin", "shop", "mall", "cosmetique"],
     "shopping_cart"),
    ("Loisirs", ["cinema", "sport", "jeu", "concert", "loisir"],
     "sports_esports"),
]

SUGGESTED_CATEGORY_MAP = {
    "Alimentation": 1, "Transport": 2, "Logement": 3, "Loisirs": 4,
    "Santé": 5, "Éducation": 6, "Shopping": 7, "Autres": 9,
}


class InvoiceScanner:
    def __init__(self):
        if not (HAS_NUMPY and HAS_CV2 and HAS_EASYOCR):
            raise RuntimeError(
                "OCR non disponible : installez opencv-python, numpy et easyocr "
                "(pip install -r requirements-ocr.txt)"
            )
        self.reader = easyocr.Reader(["fr", "en"], gpu=False)

    def preprocess(self, image_path: str) -> "np.ndarray":
        """Prétraitement OpenCV inspiré du projet cni-ocr : niveaux de gris,
        débruitage, contraste accru."""
        image = cv2.imread(image_path)
        if image is None:
            raise ValueError(f"Impossible de lire l'image : {image_path}")

        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        gray = cv2.fastNlMeansDenoising(gray, None, 15, 7, 21)
        gray = cv2.equalizeHist(gray)
        return gray

    def extract_texts(self, image_path: str) -> list[tuple[str, float]]:
        """Textes OCR avec confiance, triés par position verticale"""
        image = self.preprocess(image_path)
        results = self.reader.readtext(image, detail=1, paragraph=False)
        texts = []
        for bbox, text, conf in results:
            if conf >= 0.3:
                texts.append((text.strip(), float(conf), bbox[0][1]))
        texts.sort(key=lambda x: x[2])
        return texts

    def scan(self, image_path: str) -> dict:
        """Analyse complète d'une facture"""
        texts = self.extract_texts(image_path)
        text_only = [t[0] for t in texts]
        full_text = "\n".join(text_only)

        amount = self._extract_amount(full_text)
        date = self._extract_date(full_text)
        vendor, vendor_confidence = self._extract_vendor(texts)
        category_name, category_icon = self._suggest_category(full_text)

        return {
            "merchant": vendor,
            "merchant_confidence": vendor_confidence,
            "amount": amount["value"],
            "amount_raw": amount["raw"],
            "amount_confidence": amount["confidence"],
            "date": date,
            "suggested_category": category_name,
            "suggested_category_icon": category_icon,
            "suggested_category_id": SUGGESTED_CATEGORY_MAP.get(category_name),
            "texts": text_only,
        }

    def _extract_amount(self, full_text: str) -> dict:
        """Montant total : mot-clé TOTAL puis nombre"""
        patterns = [
            r"(?:total|totale|montant|a payer|apayer|solde)\s*[:=]?\s*([0-9][0-9\s.,]*)",
            r"(?:cfa|f cfa|fcf a|fcfa)\s*[:=]?\s*([0-9][0-9\s.,]*)",
            r"\b([0-9]{1,3}(?:[\s,.]?[0-9]{3})+(?:[,.][0-9]{1,2})?)\s*(?:cfa|f cfa|fcfa)\b",
            r"\b([0-9]+(?:[,.][0-9]{1,2})?)\b",
        ]
        for pattern in patterns:
            matches = [m for m in re.findall(pattern, full_text, re.IGNORECASE)
                       if self._parse_number(m) is not None]
            if matches:
                best = max(matches, key=lambda m: self._parse_number(m))
                return {
                    "value": self._parse_number(best),
                    "raw": best.strip(),
                    "confidence": 0.85 if re.search(r"total", full_text, re.IGNORECASE) else 0.6,
                }
        return {"value": None, "raw": None, "confidence": 0.0}

    def _extract_date(self, full_text: str) -> str | None:
        """Date au format JJ/MM/AAAA, JJ/MM/AA ou JJ-MM-AAAA"""
        for pattern in [
            r"\b(\d{2}[/-]\d{2}[/-]\d{2,4})\b",
            r"\b(\d{1,2}\s+(?:janvier|fevrier|mars|avril|mai|juin|juillet|aout|septembre"
            r"|octobre|novembre|decembre)\s+\d{4})\b",
        ]:
            match = re.search(pattern, full_text, re.IGNORECASE)
            if match:
                date_str = match.group(1)
                try:
                    if re.match(r"^\d", date_str):
                        return datetime.strptime(date_str, "%d/%m/%Y").strftime("%Y-%m-%d")
                except ValueError:
                    pass
                try:
                    return datetime.strptime(date_str, "%d/%m/%y").strftime("%Y-%m-%d")
                except ValueError:
                    pass
                try:
                    return datetime.strptime(date_str, "%d-%m-%Y").strftime("%Y-%m-%d")
                except ValueError:
                    pass
        return None

    def _extract_vendor(self, texts: list[tuple[str, float, float]]) -> tuple[str | None, float]:
        """Commerçant : première ligne en majuscules comportant des lettres"""
        for text, conf, _ in texts:
            cleaned = re.sub(r"^(?:facture|ticket|recu|reçu)\b[\s:-]*", "", text, flags=re.IGNORECASE)
            if not cleaned:
                continue
            words = cleaned.split()
            if not words:
                continue
            letters = sum(1 for c in cleaned if c.isalpha())
            if letters < 5:
                continue
            if re.search(r"\d{2}[/-]\d{2}", cleaned):
                continue
            if re.search(r"(?:total|montant|cfa|fcfa)\b", cleaned.lower()):
                continue
            title_cased = sum(1 for w in words if w and w[0].isupper())
            if title_cased >= max(1, len(words) // 2):
                return cleaned[:60], conf
        return None, 0.0

    def _suggest_category(self, full_text: str) -> tuple[str, str]:
        lower = full_text.lower()
        for name, keywords, icon in CATEGORY_KEYWORDS:
            if any(k in lower for k in keywords):
                return name, icon
        return "Autres", "more_horiz"

    @staticmethod
    def _parse_number(raw: str) -> float | None:
        """Convertit une chaîne montant en nombre (gère les espaces/virgules)"""
        try:
            s = raw.strip().replace(" ", "").replace("\u00a0", "")
            if "," in s and "." in s:
                s = s.replace(",", "") if s.rfind(".") > s.rfind(",") else s.replace(".", "")
            elif "," in s:
                s = s.replace(",", ".")
            return float(s)
        except ValueError:
            return None