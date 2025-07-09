import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import time
import os

archivo_csv = "../output/reproducciones/reproduccion.csv"  # Ajusta la ruta si es necesario

plt.ion()  # Modo interactivo (para graficar sin bloquear el flujo)

while True:
    if os.path.exists(archivo_csv):
        try:
            df = pd.read_csv(archivo_csv, names=["cycle", "x", "y", "num_crias"])
            
            # Redondear para agrupar (ajustable según tu modelo)
            df["x"] = df["x"].astype(float).round()
            df["y"] = df["y"].astype(float).round()

            heatmap_data = df.groupby(["y", "x"]).size().unstack().fillna(0)

            plt.clf()  # Limpiar figura anterior
            sns.heatmap(heatmap_data, cmap="YlOrRd")
            plt.title("Mapa de calor de reproducciones")
            plt.pause(1)  # Espera 1 segundo antes de actualizar
        except Exception as e:
            print(f"Error leyendo CSV: {e}")
    time.sleep(1)
