FROM continuumio/miniconda3:latest

RUN conda install -y -c conda-forge \
    dlib \
    opencv \
    numpy \
 && conda clean -afy

RUN pip install --no-cache-dir \
    face_recognition \
    ultralytics \
    fastapi \
    "uvicorn[standard]" \
    supabase \
    requests \
    zeroconf \
    python-multipart
    
WORKDIR /app

VOLUME ["/app/person_photos", "/app/custom_models"]

COPY server.py /app/server.py

EXPOSE 8000

CMD ["python", "server.py"]