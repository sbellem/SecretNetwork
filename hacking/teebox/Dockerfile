FROM python

ENV PYTHONUNBUFFERED=1

WORKDIR /usr/src/teebox

RUN pip install poetry

COPY poetry.lock pyproject.toml .
RUN poetry install

COPY . .

RUN poetry build && pip install dist/teebox-*.whl
