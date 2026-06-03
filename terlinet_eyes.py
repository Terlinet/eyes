import asyncio
import os
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from openai import OpenAI
from pydantic import BaseModel
from fastapi.responses import Response

app = FastAPI()

# Configuração de CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- CONFIGURAÇÃO DAS APIS ---

# Groq para Inteligência (Texto rápido)
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "SUA_GROQ_KEY")
client_groq = OpenAI(base_url="https://api.groq.com/openai/v1", api_key=GROQ_API_KEY)
MODEL_NAME = "llama-3.3-70b-versatile"

# OpenAI para Voz Neural (Super Natural)
# Certifique-se de definir a variável de ambiente OPENAI_API_KEY no seu servidor/HuggingFace
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "SUA_OPENAI_KEY")
client_openai = OpenAI(api_key=OPENAI_API_KEY)

# --- MODELOS DE DADOS ---

class VisionDetection(BaseModel):
    area_name: str
    object_type: str = "pessoa"
    severity: str = "high"

class HelperContext(BaseModel):
    event_type: str = "fall_detection"

class ChatQuestion(BaseModel):
    question: str

# --- NOVO ENDPOINT: VOZ SUPER NATURAL ---

@app.get('/tts')
async def text_to_speech(text: str):
    """
    Converte texto em áudio usando a voz neural 'nova' da OpenAI.
    'nova' é uma voz feminina, jovem, energética e extremamente natural.
    """
    try:
        response = client_openai.audio.speech.create(
            model="tts-1",
            voice="nova", # Voz feminina super natural
            input=text
        )
        # Retorna o binário do áudio MP3 diretamente para o navegador/app
        return Response(content=response.content, media_type="audio/mpeg")
    except Exception as e:
        print(f"Erro no TTS: {e}")
        return {"error": "Falha ao gerar voz neural. Verifique a API Key da OpenAI."}

# --- ENDPOINTS EXISTENTES (GROQ) ---

@app.post('/ask')
async def ask_ia(q: ChatQuestion):
    try:
        completion = client_groq.chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {"role": "system", "content": "Você é a TerlineT Eyes, uma IA de segurança e assistência de elite. Responda de forma curta, inteligente e cibernética em Português Brasil."},
                {"role": "user", "content": q.question}
            ],
            max_tokens=250
        )
        return {"message": completion.choices[0].message.content.strip()}
    except Exception as e:
        return {"message": "Erro de conexão com a rede neural."}

@app.get('/explain_system')
async def explain_system():
    try:
        completion = client_groq.chat.completions.create(
            model=MODEL_NAME,
            messages=[{"role": "user", "content": "Explique o TerlineT Eyes em 2 frases curtas e elegantes."}],
            max_tokens=150
        )
        return {"message": completion.choices[0].message.content.strip()}
    except Exception as e:
        return {"message": "TerlineT Eyes operacional. Ajuste o perímetro."}

@app.post('/vision_alert')
async def vision_alert(v: VisionDetection):
    try:
        prompt = f"Detectado {v.object_type} em {v.area_name}. Responda com uma ordem curta e autoritária de segurança."
        completion = client_groq.chat.completions.create(
            model=MODEL_NAME,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=60
        )
        return {"message": completion.choices[0].message.content.strip()}
    except Exception as e:
        return {"message": "Área restrita! Identifique-se."}

@app.get('/defense_intro')
async def defense_intro():
    try:
        completion = client_groq.chat.completions.create(
            model=MODEL_NAME,
            messages=[{"role": "user", "content": "Diga que o protocolo de defesa está ativo de forma intimidadora e curta."}],
            max_tokens=100
        )
        return {"message": completion.choices[0].message.content.strip()}
    except Exception as e:
        return {"message": "Sistema de defesa TerlineT operacional. Mira laser travada."}

@app.get('/helper_intro')
async def helper_intro():
    try:
        completion = client_groq.chat.completions.create(
            model=MODEL_NAME,
            messages=[{"role": "user", "content": "Apresente-se como TerlineT Helper de forma protetora e curta."}],
            max_tokens=100
        )
        return {"message": completion.choices[0].message.content.strip()}
    except Exception as e:
        return {"message": "Olá. Sou o seu Helper TerlineT. Estou cuidando de você."}

@app.post('/helper_check')
async def helper_check(h: HelperContext):
    try:
        completion = client_groq.chat.completions.create(
            model=MODEL_NAME,
            messages=[{"role": "user", "content": "Detectada queda. Pergunte se o usuário está bem de forma solícita."}],
            max_tokens=80
        )
        return {"message": completion.choices[0].message.content.strip()}
    except Exception as e:
        return {"message": "Você está bem? Precisa de ajuda?"}

@app.get('/helper_emergency')
async def helper_emergency():
    try:
        completion = client_groq.chat.completions.create(
            model=MODEL_NAME,
            messages=[{"role": "user", "content": "Alerta de emergência máximo! O usuário não respondeu."}],
            max_tokens=100
        )
        return {"message": completion.choices[0].message.content.strip()}
    except Exception as e:
        return {"message": "ALERTA! Chamando ajuda imediatamente!"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=7860)
