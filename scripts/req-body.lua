wrk.method = "POST"
wrk.headers["Content-Type"] = "application/json"

wrk.body = [[{
  "messages": [
    {
      "role": "user",
      "content": "Hello."
    }
  ],
  "max_completion_tokens": 50
}]]