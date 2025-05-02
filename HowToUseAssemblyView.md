# Guide d'utilisation de la vue Code Assembleur

La plateforme d'analyse de malwares inclut désormais une fonctionnalité permettant de visualiser le code assembleur des fichiers binaires analysés. Cette documentation explique comment utiliser cette nouvelle fonctionnalité.

## Types de fichiers supportés

La plateforme peut désassembler ou afficher le code source des formats suivants :

- **ELF** : Binaires Linux (exécutables, bibliothèques partagées, etc.)
- **PE32/PE64** : Binaires Windows (exécutables .exe, DLL, etc.)
- **NASM/ASM** : Fichiers de code assembleur
- **Scripts shell** : Fichiers .sh, scripts Bash, etc.
- **Code source** : Fichiers texte C/C++, Python, etc.
- **Binaires inconnus** : Affichage en hexadécimal pour les formats non reconnus

## Comment accéder à la vue Code Assembleur

1. Uploadez un fichier à analyser via l'interface web
2. Attendez que l'analyse soit complétée (statut "completed")
3. Cliquez sur le fichier dans la liste des analyses pour voir les détails
4. Dans la vue détaillée, cliquez sur le bouton "Code Assembleur"

## Interprétation des résultats

### Fichiers binaires (ELF, PE)

Pour les fichiers binaires, le désassembleur (objdump) est utilisé pour extraire le code assembleur. Le résultat inclut :

- L'adresse des instructions
- Les opcodes (code machine en hexadécimal)
- Les instructions assembleur correspondantes

Exemple :
```
0000000000401000 <_start>:
  401000:  48 31 c0              xor    rax,rax
  401003:  48 31 ff              xor    rdi,rdi
  401006:  48 31 d2              xor    rdx,rdx
  401009:  48 31 f6              xor    rsi,rsi
  40100c:  b0 3c                 mov    al,0x3c
  40100e:  0f 05                 syscall
```

### Fichiers de code source (ASM, Shell, etc.)

Pour les fichiers texte contenant du code source, le contenu est affiché directement avec une indication du type de fichier.

Exemple pour un fichier NASM :
```
section .text
global _start

_start:
    ; Write "Hello, World!" to stdout
    mov rax, 1           ; syscall number for sys_write
    mov rdi, 1           ; file descriptor 1 is stdout
    mov rsi, hello       ; pointer to message
    mov rdx, hello_len   ; message length
    syscall
    
    ; Exit
    mov rax, 60          ; syscall number for sys_exit
    xor rdi, rdi         ; status code 0
    syscall

section .data
    hello: db "Hello, World!", 10
    hello_len: equ $ - hello
```

## API REST

Vous pouvez également accéder au code assembleur via l'API REST :

```bash
curl http://localhost:8000/files/{id_analyse}/assembly
```

Le résultat est au format JSON avec les champs suivants :
- `file_id` : ID de l'analyse
- `file_name` : Nom du fichier analysé
- `file_type` : Type de fichier détecté (ELF, PE32, NASM, etc.)
- `assembly_code` : Code assembleur ou contenu source 