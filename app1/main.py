# ============================================================
# Task 1d - App Engine App 1
# Displays: name, student ID, current date and time
# ============================================================

from flask import Flask
from datetime import datetime

app = Flask(__name__)

@app.route('/')
def index():
    # Get the current date and time at the moment of the request
    now = datetime.now().strftime("%A %d %B %Y, %H:%M:%S")

    html = f"""
    <!DOCTYPE html>
    <html>
      <head>
        <title>CCWS Coursework 1 - Task 1d</title>
        <style>
          body {{ font-family: Arial, sans-serif; margin: 40px; }}
          h1 {{ color: #333; }}
          table {{ border-collapse: collapse; margin-top: 20px; }}
          td, th {{ border: 1px solid #ccc; padding: 10px 20px; }}
          th {{ background-color: #f0f0f0; }}
        </style>
      </head>
      <body>
        <h1>Cloud Computing and Web Services - Coursework 1</h1>
        <table>
          <tr><th>Field</th><th>Value</th></tr>
          <tr><td>Name</td><td>Sean Cairns</td></tr>
          <tr><td>Student ID</td><td>S2555839</td></tr>
          <tr><td>Access Time</td><td>{now}</td></tr>
        </table>
      </body>
    </html>
    """
    return html

if __name__ == '__main__':
    # Run locally on port 8080 for testing
    app.run(host='0.0.0.0', port=8080, debug=True)