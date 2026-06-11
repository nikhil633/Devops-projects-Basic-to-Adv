run:
	uvicorn app.main:app --reload --port 8000

test:
	pytest tests/ -v

build:
	docker build -t url-shortener .

up:
	docker-compose up --build
