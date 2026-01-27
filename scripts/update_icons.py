#!/usr/bin/env python3
"""
Script para atualizar os ícones do app com a nova logo.
Gera ícones com logo 30% maior (mais preenchimento).
"""

from PIL import Image
import os

# Caminhos
LOGO_PATH = r"d:\ClickeAtenda-DEV\Vs\Click-Channel\assets\images\logo.png"
ANDROID_RES = r"d:\ClickeAtenda-DEV\Vs\Click-Channel\android\app\src\main\res"

# Tamanhos para mipmap (ícone do launcher) - logo ocupa 85% do ícone (30% maior que antes)
MIPMAP_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# Tamanhos para drawable (foreground para Adaptive Icons)
DRAWABLE_SIZES = {
    "drawable-mdpi": 108,
    "drawable-hdpi": 162,
    "drawable-xhdpi": 216,
    "drawable-xxhdpi": 324,
    "drawable-xxxhdpi": 432,
}


def resize_and_save(input_path, output_path, size, fill_ratio=0.85):
    """
    Redimensiona imagem para PNG com transparência.
    fill_ratio: quanto da área o logo ocupa (0.85 = 85%)
    """
    try:
        img = Image.open(input_path)
        
        # Converte para RGBA
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
        
        # Calcula tamanho do logo (30% maior = 85% da área)
        logo_size = int(size * fill_ratio)
        
        # Redimensiona mantendo proporções
        img.thumbnail((logo_size, logo_size), Image.Resampling.LANCZOS)
        
        # Cria imagem nova com fundo transparente
        new_img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        
        # Centraliza a imagem
        offset = ((size - img.width) // 2, (size - img.height) // 2)
        new_img.paste(img, offset, img)
        
        # Salva como PNG
        new_img.save(output_path, 'PNG')
        print(f"✅ Criado: {output_path} ({size}x{size}, logo {logo_size}px)")
        return True
    except Exception as e:
        print(f"❌ Erro: {output_path}: {e}")
        return False


def main():
    print("🎨 Atualizando ícones com logo 30% MAIOR...\n")
    
    if not os.path.exists(LOGO_PATH):
        print(f"❌ Logo não encontrada: {LOGO_PATH}")
        return
    
    success = 0
    total = 0
    
    # Atualiza ícones mipmap
    print("📱 Gerando ícones do launcher (mipmap)...")
    for folder, size in MIPMAP_SIZES.items():
        total += 1
        output_dir = os.path.join(ANDROID_RES, folder)
        output_path = os.path.join(output_dir, "ic_launcher.png")
        os.makedirs(output_dir, exist_ok=True)
        if resize_and_save(LOGO_PATH, output_path, size, fill_ratio=0.85):
            success += 1
    
    # Atualiza ícones foreground
    print("\n🎨 Gerando ícones foreground (drawable)...")
    for folder, size in DRAWABLE_SIZES.items():
        total += 1
        output_dir = os.path.join(ANDROID_RES, folder)
        output_path = os.path.join(output_dir, "ic_launcher_foreground.png")
        os.makedirs(output_dir, exist_ok=True)
        # Foreground usa ratio menor pois tem padding interno
        if resize_and_save(LOGO_PATH, output_path, size, fill_ratio=0.70):
            success += 1
    
    print(f"\n✨ Concluído! {success}/{total} ícones gerados.")


if __name__ == "__main__":
    main()
