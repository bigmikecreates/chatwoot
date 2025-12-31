FROM chatwoot:development

ENV PNPM_HOME="/root/.local/share/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# Installing bundler v2.5.11 to fix compatibility issues
RUN gem install bundler -v2.5.11 --no-document

RUN chmod +x docker/entrypoints/rails.sh

EXPOSE 3000
CMD ["rails", "server", "-b", "0.0.0.0", "-p", "3000"]