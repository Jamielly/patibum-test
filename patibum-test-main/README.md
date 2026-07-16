# push_swap_tester.sh

Script de testes automatizados para o projeto **push_swap**, construído
com base no projeto. Ele roda a maior parte dos
itens verificáveis da defesa (exceto os que dependem de interação humana,
como explicação oral do código) e no final entrega um resumo de
aprovação/reprovação por seção, igual à lógica usada na correção.

## 🎯 Finalidade

Durante a correção manual, é fácil esquecer de testar algum caso, digitar
errado um argumento, ou não perceber um vazamento de memória sutil. Este
script existe para:

- **Padronizar a avaliação**: todo mundo (avaliador e avaliado) roda
  exatamente os mesmos testes, na mesma ordem da régua.
- **Economizar tempo na defesa**: em vez de digitar cada comando na mão, você
  roda um único script e já recebe o resultado de dezenas de casos.
- **Servir de checklist de autoavaliação** antes da defesa: rode o script no
  seu próprio projeto para pegar bugs, crashes e vazamentos de memória antes
  que o avaliador os encontre.
- **Reduzir subjetividade**: as métricas de número de operações e os limites
  de aprovação (ex: 100 números em menos de 2000 operações) seguem
  exatamente os valores descritos no enunciado.

## 📋 O que o script verifica

| Seção | O que testa |
|---|---|
| Pré-checagens | Presença e estrutura do `README.md` |
| Norminette | Erros de norma (se `norminette` estiver instalado) |
| Compilação | Regras do Makefile, flags `-Wall -Wextra -Werror`, ausência de relink, `make`/`clean`/`fclean`/`re` |
| Gerenciamento de erros | Argumentos não numéricos, duplicados, overflow (`MAXINT`), sem argumentos |
| Seleção de estratégia | `--simple`, `--medium`, `--complex`, `--adaptive` e comportamento padrão |
| Entradas já ordenadas | Verifica que nenhuma instrução é impressa quando a entrada já está ordenada |
| 3 e 5 números | Corretude (via checker) e qualidade do número de operações |
| Benchmark (`--bench`) | Presença do relatório e cálculo de percentual de desordem (0% / 100%) |
| 100 números | Corretude e limite de operações (excelente / bom / aceitável) |
| Comparação de flags (50 números) | Corretude de todas as flags e se `--complex` usa menos operações que `--simple` |
| 500 números | Corretude e limite de operações em larga escala |
| Vazamento de memória | Usa `valgrind` (se disponível) para detectar `definitely lost` e acessos inválidos |
| Robustez | Bateria de entradas maliciosas/estranhas para detectar segfaults e crashes |
| Checker — erros | Entradas inválidas, ações inexistentes, espaços extras |
| Checker — testes falsos | Confere que sequências que **não** ordenam retornam `KO` |
| Checker — testes corretos | Confere que sequências que ordenam corretamente retornam `OK` |

Ao final, ele imprime um **resumo por seção** (✔ passou / ✘ falhou) e uma
lista de itens que só podem ser conferidos na defesa ao vivo (número de
alunos, explicação oral dos algoritmos, exercício `--count-only`, etc.).

## ⚙️ Como usar

### 1. Dar permissão de execução

```bash
chmod +x push_swap_tester.sh
```

### 2. Rodar apontando para o repositório do projeto

```bash
./push_swap_tester.sh /caminho/para/o/repositorio
```

Se você já estiver dentro da pasta do projeto, pode simplesmente rodar:

```bash
./push_swap_tester.sh .
```

### 3. (Opcional) especificar os binários manualmente

Por padrão o script assume `./push_swap` e tenta detectar automaticamente o
checker certo para o seu sistema (`checker_linux`, `checker_Mac` ou
`fedora_checker`). Se os nomes forem diferentes, informe explicitamente:

```bash
./push_swap_tester.sh /caminho/do/repo ./push_swap ./checker_linux
```

## 📦 Requisitos

- **Bash** (Linux ou macOS)
- `shuf` — geração de números aleatórios (já vem por padrão na maioria das
  distros Linux; no macOS pode ser necessário instalar via
  `brew install coreutils` e usar `gshuf`, ou adaptar o script)
- **Opcional:** `valgrind`, para a seção de vazamento de memória
- **Opcional:** `norminette`, para a seção de norma

O script funciona mesmo sem `valgrind`/`norminette` instalados — nesse caso
ele apenas avisa e pula essas seções, para você conferir manualmente.

## 📖 Exemplo de saída

```
==================================================
  3. GERENCIAMENTO DE ERROS — push_swap
==================================================
  [OK] Parâmetros não numéricos -> Error
  [OK] Número duplicado -> Error
  [OK] Overflow (> MAXINT) -> Error
  [OK] Sem parâmetros -> nenhuma saída
  [i] Passou 4/4 (mínimo exigido: 3/4)

==================================================
  RESUMO FINAL
==================================================
  ✔ Compilação
  ✔ Gerenciamento de erros
  ✔ Seleção de estratégia (básico)
  ✘ Entradas grandes (100 números)
  ...
Seções aprovadas: 13 / 16
```

## ⚠️ Limitações

- Não substitui a defesa oral: itens como "o aluno sabe explicar o código" ou
  "ambos os alunos conseguem defender qualquer parte do projeto" exigem
  interação humana e não são automatizáveis.
- Os limites de operações (ex.: 2000 para 100 números) refletem os valores
  descritos no enunciado padrão do push_swap; se o seu assunto/campus definir
  limites diferentes, ajuste as constantes no início de cada seção do
  script.
- A detecção de vazamento de memória depende do `valgrind` estar instalado;
  em ambientes macOS sem ele, use a ferramenta `leaks` manualmente.
- O script assume que o checker aceita os mesmos argumentos do `push_swap` e
  lê instruções pela entrada padrão até `Ctrl+D`/EOF — se o seu checker tiver
  uma interface diferente, adapte a função `run_checker`.

## 🔧 Personalização rápida

Os principais pontos de ajuste ficam no topo de cada bloco do script:

- Limites de número de operações (100, 500 números) → variáveis dentro das
  seções `9.` e `11.`
- Limiares de "aceitável/bom/excelente" → mesmas seções
- Faixa de valores usados no `shuf` (ex.: `1-500`, `1-1000`) → ajuste
  conforme o enunciado do seu campus, se diferente
