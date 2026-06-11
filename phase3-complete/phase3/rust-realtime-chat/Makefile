run:
	cargo run

test:
	cargo test

build:
	cargo build --release

up:
	docker-compose up --build

# Create a room then connect two clients to test cross-pod messaging
demo:
	@echo "Creating room..."
	@ROOM_ID=$$(curl -s -X POST http://localhost:7000/rooms \
		-H "Content-Type: application/json" \
		-d '{"name":"general","description":"General chat"}' | jq -r .id) && \
	echo "Room ID: $$ROOM_ID" && \
	echo "Connect client 1: websocat ws://localhost:7000/rooms/$$ROOM_ID/ws" && \
	echo "Connect client 2: websocat ws://localhost:7001/rooms/$$ROOM_ID/ws" && \
	echo "Send: {\"user_id\":\"u1\",\"username\":\"Alice\",\"content\":\"Hello!\"}"
