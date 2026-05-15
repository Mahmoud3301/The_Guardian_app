FROM minasaher/yolov8-face-detection:latest

# Install system deps for dlib / face_recognition + avahi for mDNS
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake build-essential libopenblas-dev liblapack-dev \
    avahi-daemon avahi-utils libnss-mdns \
    && rm -rf /var/lib/apt/lists/*

# Install face_recognition + supabase client + zeroconf for mDNS
RUN pip install --no-cache-dir face_recognition supabase requests zeroconf

# Replace the default app with our custom server
COPY server.py /app/app.py

WORKDIR /app
EXPOSE 8000
CMD ["python", "app.py"]
