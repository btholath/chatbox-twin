========================================================
Setup Frontend
========================================================
bijut@b:~/aws_apps$ cd twin/
bijut@b:~/aws_apps/twin$ npx create-next-app@latest frontend --typescript --tailwind --app --no-src-dir
✔ Which linter would you like to use? › ESLint
✔ Would you like to use React Compiler? … No / Yes
✔ Would you like to customize the import alias (`@/*` by default)? … No / Yes
Creating a new Next.js app in /home/bijut/aws_apps/twin/frontend.

Using npm.

Initializing project with template: app-tw


Installing dependencies:
- next
- react
- react-dom

Installing devDependencies:
- @tailwindcss/postcss
- @types/node
- @types/react
- @types/react-dom
- babel-plugin-react-compiler
- eslint
- eslint-config-next
- tailwindcss
- typescript


added 359 packages, and audited 360 packages in 1m

142 packages are looking for funding
  run `npm fund` for details

found 0 vulnerabilities

[baseline-browser-mapping] The data in this module is over two months old.  To ensure accurate Baseline data, please update: `npm i baseline-browser-mapping@latest -D`
Generating route types...
✓ Types generated successfully

Initialized a git repository.

Success! Created frontend at /home/bijut/aws_apps/twin/frontend

bijut@b:~/aws_apps/twin$

========================================================
Install Python Package Manager (uv)
========================================================
bijut@b:~/aws_apps/twin$ curl -LsSf https://astral.sh/uv/install.sh | sh
downloading uv 0.9.13 x86_64-unknown-linux-gnu
no checksums to verify
installing to /home/bijut/.local/bin
  uv
  uvx
everything's installed!
bijut@b:~/aws_apps/twin$
bijut@b:~/aws_apps/twin$ uv --version
uv 0.9.13
=========================================================
Start the Backend Server
=========================================================
cd backend
uv init --bare
uv python pin 3.12
uv add -r requirements.txt
uv run uvicorn server:app --reload

=========================================================
Start the frontend Server
=========================================================
bijut@b:~/aws_apps/twin/frontend$ # Install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash

# Load nvm into the current shell
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100 16555  100 16555    0     0   166k      0 --:--:-- --:--:-- --:--:--  166k
=> nvm is already installed in /home/bijut/.nvm, trying to update using git
=> => Compressing and cleaning up git repository

=> nvm source string already in /home/bijut/.bashrc
=> bash_completion source string already in /home/bijut/.bashrc
=> Close and reopen your terminal to start using nvm or run the following to use it now:

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
bijut@b:~/aws_apps/twin/frontend$ nvm --version
0.39.7
bijut@b:~/aws_apps/twin/frontend$ nvm install 22
Downloading and installing node v22.21.1...
Downloading https://nodejs.org/dist/v22.21.1/node-v22.21.1-linux-x64.tar.xz...
########################################################################################################################################################################################################################## 100.0%
Computing checksum with sha256sum
Checksums matched!
Now using node v22.21.1 (npm v10.9.4)
bijut@b:~/aws_apps/twin/frontend$
nvm use 22
# or
nvm alias default 22   # make it the default in new shells
bijut@b:~/aws_apps/twin/frontend$ node -v
# should now show v22.x.x (or v20.x.x)
v22.21.1
bijut@b:~/aws_apps/twin/frontend$



cd ~/aws_apps/twin/frontend
# Optional but recommended when you bump major Node version:
rm -rf node_modules package-lock.json
npm install
npm run dev
