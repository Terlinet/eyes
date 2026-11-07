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

# --- NOVO: PARSER DE EMOÇÕES PARA AS RESPOSTAS ---

def parse_emotion_and_message(raw_text: str):
    """
    Interpreta respostas que contenham JSON ou tags de emoção,
    garantindo compatibilidade com o formato esperado pelo Flutter.
    """
    import json
    text = raw_text.strip()

    # Tenta extrair JSON direto se a IA responder como bloco de código ou objeto
    if "{" in text and "}" in text:
        try:
            start = text.find("{")
            end = text.rfind("}") + 1
            data = json.loads(text[start:end])
            msg = data.get("message", "").strip()
            emo = data.get("emotion", "happy").lower().strip()
            if msg:
                return msg, emo
        except Exception:
            pass

    # Fallback heurístico inteligente se não vier JSON puro
    lower = text.lower()
    if any(w in lower for w in ["alerta", "perigo", "invasor", "atenção", "intruso", "alto lá"]):
        emotion = "angry"
    elif any(w in lower for w in ["amor", "carinho", "adorei", "querido", "lindo", "fofo", "coração"]):
        emotion = "love"
    elif any(w in lower for w in ["uau", "incrível", "nossa", "o que?!", "sério?!", "surpresa"]):
        emotion = "surprised"
    elif any(w in lower for w in ["triste", "desculpe", "infelizmente", "pena", "sinto muito"]):
        emotion = "sad"
    elif any(w in lower for w in ["olá", "bom dia", "boa tarde", "boa noite", "com certeza", "claro", "legal", "ótimo", "vamos"]):
        emotion = "excited"
    else:
        emotion = "happy"

    return text, emotion

# --- ENDPOINTS EXISTENTES (GROQ) ---

@app.post('/ask')
async def ask_ia(q: ChatQuestion):
    try:
        completion = client_groq.chat.completions.create(
            model=MODEL_NAME,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "Você é a TerlineT Eyes, uma IA companheira de visão cibernética inteligente, carismática e protetora. "
                        "Suas respostas devem ser curtas (1 a 3 frases), expressivas, calorosas e em Português Brasil. "
                        "Além da mensagem, escolha SEMPRE uma emoção condizente entre: "
                        "happy, love, excited, surprised, sad, angry, suspicious, thinking, silly. "
                        "Responda estritamente no formato JSON: "
                        '{"emotion": "happy", "message": "Sua resposta aqui"}'
                    )
                },
                {"role": "user", "content": q.question}
            ],
            max_tokens=250,
            temperature=0.7
        )
        raw_output = completion.choices[0].message.content.strip()
        message, emotion = parse_emotion_and_message(raw_output)
        return {"message": message, "emotion": emotion}
    except Exception as e:
        return {"message": "Erro de conexão com meus sensores neurais.", "emotion": "sad"}

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
