# -------------------------
# Stage 1 : Builder
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

# Supprimer toutes les versions de bundler existantes et installer la bonne
RUN gem uninstall bundler -a -x || true && \
    gem install bundler -v "~> 2.3" --no-document

# Ajouter Bundler au PATH
ENV PATH="/usr/local/bundle/bin:$PATH"

# Copier Gemfile et Gemfile.lock (pour cache)
COPY Gemfile Gemfile.lock ./

# Installer les gems
RUN bundle install --deployment --with="docker opf_plugins" --without="test development mysql2"

# Copier le code source
COPY . $APP_PATH

# Compiler assets JS/CSS
RUN npm install && bash docker/precompile-assets.sh

# -------------------------
# Stage 2 : Runtime
# -------------------------
FROM ruby:3-slim-trixie

ENV APP_PATH=/app/openproject

WORKDIR $APP_PATH

# Installer dépendances runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 imagemagick poppler-utils tesseract-ocr unrtf catdoc nodejs \
    && rm -rf /var/lib/apt/lists/*

# Préparer dossier pour UID random OpenShift
RUN mkdir -p $APP_PATH && chgrp -R 0 $APP_PATH && chmod -R g+rwX $APP_PATH

# Copier l’application depuis le builder
COPY --from=builder /app/openproject $APP_PATH

# Exposer port OpenShift
EXPOSE 8080

# Entrypoint et CMD
ENTRYPOINT ["./docker/entrypoint.sh"]
CMD ["bash", "-c", "bundle exec rails server -b 0.0.0.0 -p 8080"]
