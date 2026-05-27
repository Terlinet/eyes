import cv2
import numpy as np
import pyttsx3
import requests
import threading
import time
import tkinter as tk
from tkinter import messagebox
from PIL import Image, ImageTk

# --- CONFIGURAÇÕES ---
HF_API_URL = "https://tertulianoshow-terlinet-eyes.hf.space/vision_alert"
COOLDOWN_SECONDS = 5
WIN_NAME = "TerlineT Eyes - Monitoramento de Elite"

# --- INICIALIZAÇÃO DA VOZ LOCAL ---
engine = pyttsx3.init()
engine.setProperty('rate', 160)
voices = engine.getProperty('voices')
for voice in voices:
    if "brazil" in voice.name.lower():
        engine.setProperty('voice', voice.id)
        break

# --- VARIÁVEIS DE ESTADO ---
last_alert_time = 0
is_processing_ai = False
polygon = []
dragging_point = None
radius = 10
monitoring_active = False

def speak_local(text):
    def _run():
        engine.say(text)
        engine.runAndWait()
    threading.Thread(target=_run, daemon=True).start()

def get_ai_brain_response(area_name):
    global is_processing_ai
    is_processing_ai = True
    try:
        payload = {"area_name": area_name, "object_type": "pessoa"}
        response = requests.post(HF_API_URL, json=payload, timeout=5)
        if response.status_code == 200:
            msg = response.json().get("message", "Atenção: Presença detectada.")
            speak_local(msg)
        else:
            speak_local("Alerta no perímetro TerlineT.")
    except:
        speak_local("Sistema em alerta. Movimentação detectada.")
    finally:
        is_processing_ai = False

def mouse_events(event, x, y, flags, param):
    global polygon, dragging_point
    if event == cv2.EVENT_LBUTTONDOWN:
        for i, (px, py) in enumerate(polygon):
            if (x - px)**2 + (y - py)**2 <= radius**2:
                dragging_point = i
                return
        polygon.append((x, y))
    elif event == cv2.EVENT_LBUTTONUP:
        dragging_point = None
    elif event == cv2.EVENT_MOUSEMOVE and dragging_point is not None:
        polygon[dragging_point] = (x, y)

def is_inside(point, poly):
    x, y = point
    n = len(poly)
    inside = False
    if n < 3: return False
    p1x, p1y = poly[0]
    for i in range(n + 1):
        p2x, p2y = poly[i % n]
        if y > min(p1y, p2y):
            if y <= max(p1y, p2y):
                if x <= max(p1x, p2x):
                    if p1y != p2y:
                        xinters = (y-p1y)*(p2x-p1x)/(p2y-p1y)+p1x
                    if p1x == p2x or x <= xinters:
                        inside = not inside
        p1x, p1y = p2x, p2y
    return inside

def start_monitoring():
    global polygon, last_alert_time, is_processing_ai, monitoring_active

    # Tenta abrir a câmera
    cap = cv2.VideoCapture(0)

    if not cap.isOpened():
        messagebox.showwarning("Câmera não detectada",
                               "Olá! Não conseguimos encontrar uma câmera ativa.\n\n"
                               "Por favor, verifique se ela está conectada ou sendo usada por outro app e tente novamente.")
        return

    monitoring_active = True
    root.withdraw() # Esconde a tela inicial

    cv2.namedWindow(WIN_NAME)
    cv2.setMouseCallback(WIN_NAME, mouse_events)

    hog = cv2.HOGDescriptor()
    hog.setSVMDetector(cv2.HOGDescriptor_getDefaultPeopleDetector())

    # Polígono Inicial
    polygon = [(150, 100), (490, 100), (490, 380), (150, 380)]

    while monitoring_active:
        ret, frame = cap.read()
        if not ret:
            messagebox.showerror("Erro de Vídeo", "A conexão com a câmera foi perdida.")
            break

        frame = cv2.flip(frame, 1)

        if len(polygon) > 0:
            pts = np.array(polygon, np.int32).reshape((-1, 1, 2))
            cv2.polylines(frame, [pts], True, (0, 255, 0), 2)
            for (x, y) in polygon:
                cv2.circle(frame, (x, y), radius, (255, 0, 0), -1)

        rects, _ = hog.detectMultiScale(frame, winStride=(8, 8), padding=(8, 8), scale=1.05)

        invasion = False
        for (x, y, w, h) in rects:
            center = (x + w//2, y + h//2)
            if is_inside(center, polygon):
                invasion = True
                cv2.rectangle(frame, (x, y), (x+w, y+h), (0, 0, 255), 2)
            else:
                cv2.rectangle(frame, (x, y), (x+w, y+h), (255, 255, 0), 1)

        now = time.time()
        if invasion and not is_processing_ai:
            if now - last_alert_time > COOLDOWN_SECONDS:
                last_alert_time = now
                threading.Thread(target=get_ai_brain_response, args=("Área Monitorada",), daemon=True).start()

        status_text = "SISTEMA ATIVO" if not invasion else "INVASAO!"
        status_color = (0, 255, 0) if not invasion else (0, 0, 255)
        cv2.putText(frame, f"STATUS: {status_text}", (20, 40), cv2.FONT_HERSHEY_DUPLEX, 0.8, status_color, 2)

        if is_processing_ai:
            cv2.putText(frame, "Processando IA...", (20, 70), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 1)

        cv2.imshow(WIN_NAME, frame)
        key = cv2.waitKey(1) & 0xFF
        if key == ord('q'):
            monitoring_active = False
            break
        if key == ord('r'):
            polygon = [(150, 100), (490, 100), (490, 380), (150, 380)]

    cap.release()
    cv2.destroyAllWindows()
    root.deiconify() # Mostra a tela inicial de volta

# --- INTERFACE GRÁFICA (TKINTER) ---
root = tk.Tk()
root.title("TerlineT Eyes v1.0")
root.geometry("400x300")
root.configure(bg="#2c3e50")

# Centralizar Janela
window_width = 400
window_height = 300
screen_width = root.winfo_screenwidth()
screen_height = root.winfo_screenheight()
center_x = int(screen_width/2 - window_width / 2)
center_y = int(screen_height/2 - window_height / 2)
root.geometry(f'{window_width}x{window_height}+{center_x}+{center_y}')

label_title = tk.Label(root, text="TerlineT Eyes", font=("Helvetica", 24, "bold"), fg="#ecf0f1", bg="#2c3e50")
label_title.pack(pady=30)

label_subtitle = tk.Label(root, text="Monitoramento Inteligente de Elite", font=("Helvetica", 10), fg="#bdc3c7", bg="#2c3e50")
label_subtitle.pack(pady=5)

btn_start = tk.Button(root, text="INICIAR MONITORAMENTO", font=("Helvetica", 12, "bold"),
                      bg="#27ae60", fg="white", padx=20, pady=10, relief="flat",
                      command=start_monitoring)
btn_start.pack(pady=40)

label_footer = tk.Label(root, text="Governance & Vision System", font=("Helvetica", 8), fg="#7f8c8d", bg="#2c3e50")
label_footer.pack(side="bottom", pady=10)

if __name__ == "__main__":
    root.mainloop()
