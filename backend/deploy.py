import os
import shutil
import zipfile
import subprocess
import stat


def remove_readonly(func, path, excinfo):
    """Error handler for Windows/Linux readonly files"""
    os.chmod(path, stat.S_IWRITE)
    func(path)


def cleanup():
    """Clean up old build artifacts"""
    print("Cleaning up old artifacts...")
    
    # Remove lambda-package
    if os.path.exists("lambda-package"):
        try:
            shutil.rmtree("lambda-package", onerror=remove_readonly)
        except Exception as e:
            print(f"Warning: Could not remove lambda-package: {e}")
            print("Trying with sudo...")
            subprocess.run(["sudo", "rm", "-rf", "lambda-package"], check=False)
    
    # Remove old zip
    if os.path.exists("lambda-deployment.zip"):
        try:
            os.remove("lambda-deployment.zip")
        except Exception as e:
            print(f"Warning: Could not remove zip: {e}")
            subprocess.run(["sudo", "rm", "-f", "lambda-deployment.zip"], check=False)


def main():
    print("Creating Lambda deployment package...")

    # Clean up
    cleanup()

    # Create package directory
    os.makedirs("lambda-package", exist_ok=True)

    # Install dependencies using Docker with Lambda runtime image
    print("Installing dependencies for Lambda runtime...")

    # Use the official AWS Lambda Python 3.12 image
    # This ensures compatibility with Lambda's runtime environment
    try:
        subprocess.run(
            [
                "docker",
                "run",
                "--rm",
                "-v",
                f"{os.getcwd()}:/var/task",
                "--platform",
                "linux/amd64",  # Force x86_64 architecture
                "--entrypoint",
                "",  # Override the default entrypoint
                "public.ecr.aws/lambda/python:3.12",
                "/bin/sh",
                "-c",
                "pip install --target /var/task/lambda-package -r /var/task/requirements.txt --platform manylinux2014_x86_64 --only-binary=:all: --upgrade",
            ],
            check=True,
        )
    except subprocess.CalledProcessError as e:
        print(f"Error installing dependencies: {e}")
        print("Make sure Docker is running and you have internet access.")
        return

    # Copy application files
    print("Copying application files...")
    app_files = ["server.py", "lambda_handler.py", "context.py", "resources.py"]
    for file in app_files:
        if os.path.exists(file):
            shutil.copy2(file, "lambda-package/")
        else:
            print(f"Warning: {file} not found, skipping...")

    # Copy data directory
    if os.path.exists("data"):
        print("Copying data directory...")
        shutil.copytree("data", "lambda-package/data", dirs_exist_ok=True)
    else:
        print("Warning: data/ directory not found!")

    # Create zip
    print("Creating zip file...")
    with zipfile.ZipFile("lambda-deployment.zip", "w", zipfile.ZIP_DEFLATED) as zipf:
        for root, dirs, files in os.walk("lambda-package"):
            for file in files:
                file_path = os.path.join(root, file)
                arcname = os.path.relpath(file_path, "lambda-package")
                zipf.write(file_path, arcname)

    # Show package size
    size_mb = os.path.getsize("lambda-deployment.zip") / (1024 * 1024)
    print(f"✓ Created lambda-deployment.zip ({size_mb:.2f} MB)")
    
    # Check size limits
    if size_mb > 50:
        print(f"⚠️  WARNING: Package is large ({size_mb:.2f} MB)")
        print("   Lambda direct upload limit: 50 MB")
        print("   Consider using S3 for deployment or reducing dependencies")
    
    if size_mb > 250:
        print(f"❌ ERROR: Package too large ({size_mb:.2f} MB)")
        print("   Lambda uncompressed limit: 250 MB")
        print("   You must reduce package size")


if __name__ == "__main__":
    main()
