# ---------- Stage 1: Builder ----------
FROM registry.access.redhat.com/ubi9/ruby-31:1-47 AS builder


# Variables d'environnement
ENV APP_USER=openproject \
    APP_PATH=/app/openproject

WORKDIR $APP_PATH

# Installer dépendances système pour build
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      curl \
      git \
      nodejs \
      npm \
      libpq-dev \
      imagemagick \
      poppler-utils \
      tesseract-ocr \
      unrtf \
      catdoc && \
    rm -rf /var/lib/apt/lists/*

# Installer bundler
RUN gem install bundler --no-document

# Copier uniquement les fichiers nécessaires pour installer les gems
COPY Gemfile Gemfile.lock ./
RUN bundle install --deployment --without="test development mysql2"

# Copier le reste du code
COPY . $APP_PATH

# Compiler les assets (JS, CSS…)
RUN npm install && \
    bash docker/precompile-assets.sh

# ---------- Stage 2: Runtime ----------
FROM registry.access.redhat.com/ubi9/ruby-31:1-47

ENV APP_USER=openproject \
    APP_PATH=/app/openproject

WORKDIR $APP_PATH

# Installer dépendances runtime
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      curl \
      nodejs \
      npm \
      libpq-dev \
      apache2 \
      imagemagick \
      poppler-utils \
      tesseract-ocr \
      unrtf \
      catdoc \
      memcached \
      postfix && \
    rm -rf /var/lib/apt/lists/*

# Créer utilisateur non-root
RUN useradd -d /home/$APP_USER -m $APP_USER

# Copier l'application depuis l'image builder
COPY --from=builder /app/openproject $APP_PATH

# Apache config
RUN a2enmod proxy proxy_http && rm -f /etc/apache2/sites-enabled/000-default.conf

# Exposer uniquement le port web
EXPOSE 80

# Volumes pour données persistantes
VOLUME ["/app/openproject/files", "/app/openproject/log"]

# Entrypoint & CMD
USER $APP_USER
ENTRYPOINT ["./docker/entrypoint.sh"]
CMD ["bash", "-c", "bundle exec rails server -b 0.0.0.0 -p 80"]

