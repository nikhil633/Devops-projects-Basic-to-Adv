const request = require("supertest");
const app = require("../src/app");

jest.mock("../src/services/notificationService", () => ({
  enqueue: jest.fn().mockResolvedValue("test-id-123"),
  getStatus: jest.fn().mockResolvedValue({
    id: "test-id-123",
    type: "email",
    recipient: "user@example.com",
    message: "Hello",
    status: "sent",
    createdAt: new Date().toISOString(),
  }),
}));

test("GET /health returns ok", async () => {
  const res = await request(app).get("/health");
  expect(res.statusCode).toBe(200);
  expect(res.body.status).toBe("ok");
});

test("POST /notify returns 202 with id", async () => {
  const res = await request(app)
    .post("/notify")
    .send({ type: "email", recipient: "user@example.com", message: "Hello" });
  expect(res.statusCode).toBe(202);
  expect(res.body.id).toBe("test-id-123");
});

test("GET /status/:id returns status", async () => {
  const res = await request(app).get("/status/test-id-123");
  expect(res.statusCode).toBe(200);
  expect(res.body.status).toBe("sent");
});

test("POST /notify returns 400 when fields missing", async () => {
  const res = await request(app).post("/notify").send({ type: "email" });
  expect(res.statusCode).toBe(400);
});
