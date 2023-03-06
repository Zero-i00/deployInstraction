FROM python:3

SHELL ["/bin/bash", "-c"]

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

RUN pip install --upgrade pip

RUN useradd -rms /bin/bash deployInstraction && chmod 777 /opt /run

WORKDIR /deployInstraction
RUN mkdir /deployInstraction/static && mkdir /deployInstraction/media && chown -R deployInstraction:deployInstraction /deployInstraction && chmod 775 /deployInstraction>

COPY --chown=deployInstraction:deployInstraction . .

RUN pip install -r requirements.txt

USER deployInstraction

CMD ["gunicorn", "-b", "0.0.0.0:8000", "deployInstraction.wsgi:application"]