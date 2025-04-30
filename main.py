from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

app = FastAPI()

# Setup Jinja2 templates directory
templates = Jinja2Templates(directory="templates")

# API 1: Return user name in JSON
@app.get("/user/{name}")
def get_user_name(name: str):
    return {"name": name}

# API 2: Render HTML page with user's name
@app.get("/user_html/{name}", response_class=HTMLResponse)
def get_user_page(request: Request, name: str):
    return templates.TemplateResponse("user.html", {"request": request, "name": name})

@app.get("/counter")
def counter():
    return templates.TemplateResponse("counter.html")

@app.get("/color")
def color():
    return templates.TemplateResponse("colorpicker.html")
