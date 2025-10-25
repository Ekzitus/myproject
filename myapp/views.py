from django.http import HttpResponse
from django.contrib.auth.decorators import login_required
from django.shortcuts import render


@login_required
def index(request):
    return render(request, "myapp/index.html", {"message": "Hello World!"})
