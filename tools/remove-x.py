import sys, os
import io
import math
from pathlib import Path


def removix(input_path: Path) -> Path:

    path = str(input_path)
    if not '-x.png' in path: return
    if os.path.exists(path.replace('-x.png','.png')): os.remove(path.replace('-x.png','.png'))
    os.rename(path,path.replace('-x.png','.png'))

def main():
    if len(sys.argv) < 2:
        print("ERREUR : aucun fichier fourni.")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    if not input_path.exists():
        print(f"ERREUR : fichier introuvable : {input_path}")
        sys.exit(1)

    print(f"Traitement de : {input_path.name} ...")
    output_path = removix(input_path)


if __name__ == "__main__":
    main()
