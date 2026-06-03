import asyncio
import os
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from openai import OpenAI
from pydantic import BaseModel

app = FastAPI()

# Configuração de CORS para permitir acesso do Flutter Web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuração da API GROQ (ou OpenAI)
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "SUA_CHAVE_AQUI")
client_groq = OpenAI(base_url="https://api.groq.com/openai/v1", api_key=GROQ_API_KEY)
MODEL_NAME = "llama-3.3-70b-versatile"

# --- MODELOS DE DADOS ---

class VisionDetection(BaseModel):
    area_name: str
    object_type: str = "pessoa"
    severity: str = "high"  # Sincronizado com o main.dart

class HelperContext(BaseModel):
    event_type: str = "fall_detection"

class ChatQuestion(BaseModel):
    question: str

# --- ENDPOINTS SISTEMA DE MONITORAMENTO (MONITOR PAGE) ---

@app.post('/ask')
@app.post('/ask/')
async def ask_ia(q: ChatQuestion):
    try:
        completion = client_groq.chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {"role": "system", "content": "Você é a TerlineT Eyes, uma IA de segurança e assistência de elite. Responda de forma curta, inteligente e cibernética."},
                {"role": "user", "content": q.question}
            ],
            max_tokens=250
        )
        return {"message": completion.choices[0].message.content.strip()}
    except Exception as e:
        print(f"Erro no endpoint /ask: {e}")
        return {"message": "Protocolo de comunicação interrompido. Verifique minha conexão com a rede neural."}

@app.get('/explain_system')
async def explain_system():
    try:
        prompt = (
            "Você é a TerlineT Eyes, uma IA de segurança de elite. "
            "Explique de forma curta (máximo 3 frases) e elegante que o sistema usa visão computacional para monitorar perímetros, "
            "que o usuário deve ajustar a zona verde e que qualquer intrusão disparará um alerta. "
            "Seja profissional e autoritária."
        )
        completion = client_groq.chat.completions.create(
            model=MODEL_NAME,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=150
        )
        return {"message": completion.choices[0].message.content.strip()}
    except Exception as e:
        return {"message": "Bem-vindo. Sou a TerlineT Eyes. Ajuste o perímetro de segurança. Estou operacional."}

@app.post('/vision_alert')
async def vision_alert(v: VisionDetection):
    try:
        prompt = (
            f"TerlineT Eyes detectou {v.object_type} em {v.area_name} com severidade {v.severity}. "
            f"Aborde o invasor de forma curta, agressiva e autoritária para dissuasão."
        )
        completion = client_groq.chat.completions.create(
            model=MODEL_NAME,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=60
        )
        return {"message": completion.choices[0].message.content.strip()}
    except Exception as e:
        return {"message": "Área restrita. Identifique-se imediatamente ou medidas de segurança serão tomadas."}

# --- ENDPOINTS SISTEMA DE DEFESA (DEFENSE PAGE) ---

@app.get('/defense_intro')
async def defense_intro():
    try:
        prompt = (
            "Você é o Sistema de Defesa TerlineT, uma IA tática de combate. "
            "Diga de forma curta e intimidadora que o protocolo de defesa ativa está online, "
            "as miras laser estão calibradas e qualquer invasão será neutralizada imediatamente."
        )
        completion = client_groq.chat.completions.create(
            model=MODEL_NAME,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=100
        )
        return {"message": completion.choices[0].message.content.strip()}
    except Exception as e:
        return {"message": "Sistema de defesa TerlineT operacional. Mira laser travada. Perímetro sob custódia."}

# --- ENDPOINTS SISTEMA HELPER (ASSISTANCE PAGE) ---

@app.get('/helper_intro')
async def helper_intro():
    try:
        prompt = (
            "Você é o TerlineT Helper, um assistente de monitoramento de saúde e segurança pessoal de elite. "
            "Apresente-se de forma curta, elegante e protetora. Diga que está monitorando para garantir o bem-estar do usuário."
        )
        completion = client_groq.chat.completions.create(
            model=MODEL_NAME,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=100
        )
        return {"message": completion.choices[0].message.content.strip()}
    except Exception as e:
        return {"message": "Olá. Sou o seu Helper TerlineT. Estou monitorando o ambiente para sua total segurança."}

@app.post('/helper_check')
async def helper_check(h: HelperContext):
    try:
        prompt = (
            f"Você é o TerlineT Helper. Você detectou um evento de {h.event_type} (possível queda). "
            f"Pergunte se o usuário está bem e se precisa de ajuda. Seja solícito porém mantendo o padrão de IA de elite."
        )
        completion = client_groq.chat.completions.create(
            model=MODEL_NAME,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=80
        )
        return {"message": completion.choices[0].message.content.strip()}
    except Exception as e:
        return {"message": "Você está bem? Percebi um movimento atípico. Precisa de ajuda?"}

@app.get('/helper_emergency')
async def helper_emergency():
    try:
        prompt = (
            "Você é o TerlineT Helper. O usuário não respondeu a um check de segurança após uma queda. "
            "Grite (em texto) um alerta de emergência máximo. Diga que está chamando socorro agora. "
            "Seja extremamente urgente e autoritário."
        )
        completion = client_groq.chat.completions.create(
            model=MODEL_NAME,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=100
        )
        return {"message": completion.choices[0].message.content.strip()}
    except Exception as e:
        return {"message": "ALERTA MÁXIMO! Nenhuma resposta detectada. Iniciando protocolo de emergência e chamando ajuda IMEDIATAMENTE!"}

if __name__ == "__main__":
    # Rodando na porta padrão do Hugging Face Spaces ou local
    uvicorn.run(app, host="0.0.0.0", port=7860)
