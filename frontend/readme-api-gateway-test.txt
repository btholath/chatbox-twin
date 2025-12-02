
https://jcutgkjg7i.execute-api.us-east-1.amazonaws.com/

{"message":"AI Digital Twin API (Powered by AWS Bedrock)","memory_enabled":true,"storage":"S3","ai_model":"us.amazon.nova-lite-v1:0"}


curl -X POST https://jcutgkjg7i.execute-api.us-east-1.amazonaws.com/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello, who are you?"}'


bijut@b:~/aws_apps/twin/frontend$ curl -X POST https://jcutgkjg7i.execute-api.us-east-1.amazonaws.com/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello, who are you?"}'
{"response":"Hello! I'm Biju Tholath, but you can call me Biju. I'm an AI/ML Engineer based in Los Angeles, and I'm here to assist you with any questions you might have about my professional background, my work, or any topics related to AI and machine learning. How can I help you today?","session_id":"4db7f51e-1e78-4428-be64-9b9e339c0d9a"}bijut@b:~/aws_apps/twin/frontend$

