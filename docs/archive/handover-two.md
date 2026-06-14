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


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


curl https://api.anthropic.com/v1/messages \
  --header "x-api-key: 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" \
  --header "anthropic-version: 2023-06-01" \
  --header "content-type: application/json" \
  --data '{"model": "claude-sonnet-4-6", "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Hello, world"}]}'