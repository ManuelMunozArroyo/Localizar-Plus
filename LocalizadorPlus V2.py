# -*- coding: utf-8 -*-
"""
LOCALIZADOR PLUS - arranque en el ordenador
--------------------------------------
Abre el Localizador (el mismo programa que el movil) en su propia
ventana de Edge, abajo a la derecha de la pantalla.

Por que hace falta este arranque: si el programa se abre como un
archivo normal, Edge pregunta "Bloquear o Permitir" el microfono cada
vez. Aqui se sirve como una pequena web SOLO dentro de este ordenador
(http://localhost), y asi Edge pregunta una sola vez y lo recuerda
para siempre. No se envia nada a internet: solo este ordenador puede
ver esa direccion.
"""

import os
import sys
import socket
import subprocess
import http.server
import threading
import functools

PUERTO = 47622          # el de Localizador Plus (distinto del Localizador v50, 47621)
DIRECCION = f"http://localhost:{PUERTO}/"

# La ventana se abre MAXIMIZADA, ocupando toda la pantalla, y sin
# nada del navegador alrededor: solo se ve el programa.


def carpeta_del_programa():
    if getattr(sys, "frozen", False):
        return os.path.dirname(sys.executable)
    return os.path.dirname(os.path.abspath(__file__))


CARPETA = carpeta_del_programa()


def ya_esta_funcionando():
    try:
        with socket.create_connection(("127.0.0.1", PUERTO), timeout=0.5):
            return True
    except OSError:
        return False


def buscar_edge():
    posibles = [
        os.path.join(os.environ.get("ProgramFiles(x86)", ""), "Microsoft", "Edge", "Application", "msedge.exe"),
        os.path.join(os.environ.get("ProgramFiles", ""), "Microsoft", "Edge", "Application", "msedge.exe"),
        os.path.join(os.environ.get("LOCALAPPDATA", ""), "Microsoft", "Edge", "Application", "msedge.exe"),
    ]
    for ruta in posibles:
        if ruta and os.path.isfile(ruta):
            return ruta
    return None


def sitio_de_la_ventana():
    """Maximizada, a toda la pantalla."""
    return ["--start-maximized"]


VENTANA = None          # la ventana de Edge que hemos abierto


def abrir_ventana(direccion):
    global VENTANA
    edge = buscar_edge()
    if not edge:
        import webbrowser
        webbrowser.open(direccion)
        return None
    perfil = os.path.join(CARPETA, "perfil")
    orden = [edge, f"--user-data-dir={perfil}", "--no-first-run",
             "--no-default-browser-check", f"--app={direccion}"] + sitio_de_la_ventana()
    VENTANA = subprocess.Popen(orden)
    return VENTANA


class SoloEstaCarpeta(http.server.SimpleHTTPRequestHandler):
    """Solo entrega el programa y su icono; nada mas del ordenador."""

    PERMITIDOS = {"/": "LocalizadorPlus V2.html", "/index.html": "LocalizadorPlus V2.html",
                  "/icono.ico": "LocalizadorPlus V2.ico", "/favicon.ico": "LocalizadorPlus V2.ico"}

    def do_GET(self):
        ruta = self.path.split("?")[0].lower()
        if ruta == "/cerrar":
            # Le has dicho "adios": se cierra la ventana y se apaga todo.
            self.send_response(200)
            self.send_header("Content-Length", "2")
            self.end_headers()
            try:
                self.wfile.write(b"ok")
                self.wfile.flush()
            except Exception:
                pass
            threading.Thread(target=cerrar_del_todo, daemon=True).start()
            return
        nombre = self.PERMITIDOS.get(ruta)
        archivo = os.path.join(CARPETA, nombre) if nombre else None
        if not archivo or not os.path.isfile(archivo):
            self.send_error(404)
            return
        with open(archivo, "rb") as f:
            datos = f.read()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8" if archivo.endswith(".html") else "image/x-icon")
        self.send_header("Content-Length", str(len(datos)))
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(datos)

    def log_message(self, *args):
        pass


def cerrar_del_todo():
    """Cierra la ventana del Localizador y apaga el arranque."""
    import time
    time.sleep(0.4)
    try:
        if VENTANA is not None:
            VENTANA.terminate()
            try:
                VENTANA.wait(timeout=5)
            except Exception:
                VENTANA.kill()
    except Exception:
        pass
    os._exit(0)


def main():
    # Si ya esta abierto de antes, solo se abre otra ventana.
    if ya_esta_funcionando():
        abrir_ventana(DIRECCION)
        return

    try:
        servidor = http.server.ThreadingHTTPServer(("127.0.0.1", PUERTO), SoloEstaCarpeta)
    except OSError:
        # Si no se puede, se abre como archivo (preguntara el permiso).
        ruta = os.path.join(CARPETA, "LocalizadorPlus V2.html").replace("\\", "/")
        abrir_ventana("file:///" + ruta.replace(" ", "%20") + "?app=1")   # ?app=1: abierto desde el icono
        return

    abrir_ventana(DIRECCION)
    # Se queda encendido en segundo plano (no gasta nada): asi, cada vez
    # que pulsas el icono, la ventana se abre al instante.
    servidor.serve_forever()


if __name__ == "__main__":
    main()
