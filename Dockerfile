# -------------------------
# Build stage
# -------------------------
FROM ruby:3-slim-trixie AS builder

ENV APP_PATH=/app/openproject

WORKDIR $APP_PATH

# Installer dépendances build
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git curl gnupg \
    libpq-dev libmagickwand-dev libxml2-dev libxslt1-dev \
    nodejs npm \
    imagemagick poppler-utils tesseract-ocr unrtf catdoc \
    && rm -rf /var/lib/apt/lists/*

# Supprimer les anciennes versions de bundler et installer la bonne
RUN gem uninstall bundler -a -x || true && \
    gem install bundler -v "~> 2.3" --no-document

ENV BUNDLER_VERSION="~>2.3"

# Copier Gemfile et Gemfile.lock avant tout (meilleur cache)
COPY Gemfile Gemfile.lock ./

# Utiliser bundler forcé à la bonne version
RUN bundle _2.3.26_ install \
    --deployment \
    --with="docker opf_plugins" \
    --without="test development mysql2"

# Copier tout le code source
COPY . $APP_PATH

# Compiler assets
RUN npm install && bash docker/precompile-assets.sh

# -------------------------
# Runtime stage
# -------------------------
FROM ruby:3-slim-trixie

ENV APP_PATH=/app/openproject

WORKDIR $APP_PATH

# Installer dépendances runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 imagemagick poppler-utils tesseract-ocr unrtf catdoc nodejs \
    && rm -rf /var/lib/apt/lists/*

# Fix permissions pour OpenShift (UID random)
RUN mkdir -p $APP_PATH && chgrp -R 0 $APP_PATH && chmod -R g+rwX $APP_PATH

# Copier depuis le builder
COPY --from=builder /app/openproject $APP_PATH

# OpenShift recommande d'exposer 8080
EXPOSE 8080

ENTRYPOINT ["./docker/entrypoint.sh"]
CMD ["bash", "-c", "bundle exec rails server -b 0.0.0.0 -p 8080"]
