# patibum-test

Suíte de testes automatizados para o projeto **push_swap** da 42, com
checker próprio incluído. Roda a régua de avaliação inteira — compilação,
norma, gerenciamento de erros, corretude, performance, memória e robustez —
com um único comando, e termina com um resumo claro de aprovação por seção.

![Shell](https://img.shields.io/badge/shell-bash-4EAA25.svg)
![C](https://img.shields.io/badge/C-checker%20próprio-blue.svg)
![Status](https://img.shields.io/badge/status-estável-success.svg)

---

## 📂 Estrutura

```
.
├── Makefile             # compila o checker e roda o tester com um comando
├── checker.c             # checker próprio, mesma régua de erro do push_swap
├── push_swap_tester.sh   # script principal com as 16 seções de teste
└── README.md
```

Os três arquivos (`Makefile`, `checker.c`, `push_swap_tester.sh`) precisam
ficar **juntos, na mesma pasta**. Essa pasta pode estar dentro do repositório
do aluno (numa subpasta, ex. `tester/`) ou em qualquer outro lugar — o
importante é sempre indicar corretamente qual pasta contém o `push_swap` a
ser avaliado (veja [Como usar](#-como-usar)).

---

## 🎯 Por que existe

Corrigir `push_swap` na mão é repetitivo e fácil de errar: esquecer um caso
de erro, digitar o argumento errado, não perceber um vazamento de memória
sutil escondido em 500 números aleatórios. Este projeto existe para:

- **Padronizar a avaliação** — todo mundo roda exatamente os mesmos casos,
  na mesma ordem, com os mesmos limites de operações do enunciado.
- **Economizar tempo na defesa** — um comando substitui dezenas de
  chamadas manuais ao `push_swap` e ao checker.
- **Servir de autoavaliação** — rode no seu próprio projeto antes da
  defesa para pegar bugs, crashes e leaks antes do avaliador.
- **Não depender de binário externo** — o checker é compilado localmente
  a partir do `checker.c`, então não há risco de permissão perdida,
  arquitetura incompatível (x86/ARM) ou binário ausente.

---

## ⚙️ Como usar

### 1. Compilar o checker

```bash
make checker
```

Compila `checker.c` com `-Wall -Wextra -Werror` e gera `./checker_linux`.

### 2. Rodar os testes

```bash
make test REPO=/caminho/para/o/repositorio/do/aluno
```

Se não passar `REPO`, assume o diretório atual (`.`). `make test` compila o
checker automaticamente se ainda não existir.

### 3. Rodar o script diretamente (sem make)

```bash
chmod +x push_swap_tester.sh
./push_swap_tester.sh <pasta_do_repo> <bin_push_swap> <bin_checker>

ex.: "./tester_v3/push_swap_tester.sh" . ./push_swap "./tester_v3/checker_linux"
```

Os três argumentos são **posicionais e opcionais**:

| Argumento | Padrão | Observação |
|---|---|---|
| `pasta_do_repo` | `.` (diretório atual) | Pasta que contém o `Makefile`/`README.md` do aluno |
| `bin_push_swap` | `./push_swap` | Caminho **relativo à `pasta_do_repo`**, não à pasta de onde você chama o script |
| `bin_checker` | detectado automaticamente (`checker_linux`, `checker_Mac` ou `fedora_checker`) | Também relativo à `pasta_do_repo` |

> ⚠️ **A pegadinha mais comum**: se o tester estiver numa subpasta dentro
> do repo do aluno (ex. `push_swap_aluno/tester/`), e você rodar o script
> de dentro dela, o caminho do checker/push_swap **não é** relativo a onde
> você está — é relativo à `pasta_do_repo` que você passou. Exemplo real:
>
> ```bash
> cd push_swap_aluno/tester
> ./push_swap_tester.sh .. ./push_swap ./tester/checker_linux
> ```

Assim que o script inicia, ele imprime um bloco **CONFIGURAÇÃO DESTA
EXECUÇÃO** mostrando exatamente qual pasta, binário e checker foram
resolvidos — confira sempre essa primeira tela antes de interpretar
qualquer resultado.

---

## 📋 O que cada seção verifica

| # | Seção | O que testa |
|---|---|---|
| 0 | Pré-checagens | Presença do `README.md`, autores no git log |
| 1 | Norminette | Erros de norma (se `norminette` estiver instalado) |
| 2 | Compilação | Regras do Makefile, flags `-Wall -Wextra -Werror`, ausência de relink, `make`/`clean`/`fclean`/`re` |
| 3 | Gerenciamento de erros | Argumentos não numéricos, duplicados, overflow (`MAXINT`), sem argumentos |
| 4 | Seleção de estratégia | `--simple`, `--medium`, `--complex`, `--adaptive` e comportamento padrão |
| 5 | Entradas já ordenadas | Nenhuma instrução impressa quando a entrada já está ordenada |
| 6 / 7 | 3 e 5 números | Corretude (via checker) e qualidade do número de operações |
| 8 | Benchmark (`--bench`) | Presença do relatório e cálculo de percentual de desordem (0% / 100%) |
| 9 | 100 números | Corretude e limite de operações (excelente / bom / aceitável) |
| 10 | Comparação de flags (50 números) | Corretude de todas as flags e se `--complex` usa menos operações que `--simple` |
| 11 | 500 números | Corretude e limite de operações em larga escala |
| 12 | Vazamento de memória | `valgrind` (se disponível) — vazamentos definitivos e acessos inválidos |
| 13 | Robustez | Bateria de entradas maliciosas/estranhas para detectar crashes |
| 14–16 | Checker | Gerenciamento de erros do próprio checker, testes que devem dar `KO` e testes que devem dar `OK` |

Ao final, um **resumo por seção** (✔/✘, sempre na ordem em que rodaram) e
uma lista de itens que só a defesa ao vivo confirma (número de alunos,
explicação oral dos algoritmos, exercício `--count-only`, etc.).

---

## 🧠 Sobre o checker próprio

`checker.c` é uma implementação independente do checker da 42: lê a pilha
inicial pelos argumentos, aplica as 11 operações (`sa sb ss pa pb ra rb rr
rra rrb rrr`) lidas da entrada padrão até `EOF`, e imprime `OK`/`KO`
conforme o estado final da pilha. Segue a mesma régua de erro do
`push_swap`:

- Argumento não numérico, duplicado ou fora do intervalo de `int` → `Error`
  no `stderr`, saída 1.
- Instrução desconhecida ou com espaços extras → `Error`.
- Pilha vazia (sem números) e sem instruções → `OK` (trivialmente
  ordenada).

Compila com `cc -Wall -Wextra -Werror checker.c -o checker_linux` — sem
dependências além da libc.

---

## 🩺 Troubleshooting (erros reais que já apareceram)

| Sintoma | Causa | Solução |
|---|---|---|
| Só a Norminette passa, resto nem aparece | Script achou o binário errado e abortou cedo | Confira o bloco "CONFIGURAÇÃO DESTA EXECUÇÃO" no topo — o caminho do `push_swap` está certo? |
| `checker OK (obteve '')` em várias seções | Caminho do checker tem **espaço** (ex. `tester 3.0/checker_linux`) — corrigido nesta versão, mas confirme que está usando o `.sh` atualizado | Atualize para a versão mais recente do script |
| Norminette reprovando `checker.c` | O tester está **dentro** do repositório avaliado, e o script pegou o próprio `checker.c` do tester no lugar do código do aluno | Nesta versão isso é detectado e excluído automaticamente; se ainda acontecer, confirme que está rodando a versão mais recente |
| `[AVISO] Nenhum binário checker executável encontrado` | O `checker_linux` não está na pasta esperada, ou está sem `chmod +x` | O script já tenta `chmod +x` sozinho; se persistir, `make checker` e aponte o caminho certo no 3º argumento |
| Vazamento "detectado" mas sem detalhe nenhum | Formato de saída do valgrind não bateu com o padrão esperado (ex. `no leaks are possible` em vez de `definitely lost: 0 bytes`) | Corrigido nesta versão — agora reconhece as duas formas, e sempre mostra a saída completa quando não reconhece o formato |
| Resumo final em ordem estranha | Iterava um array associativo do bash, que não garante ordem | Corrigido — agora segue a ordem real de execução (seção 3 → 16) |
| `make test` não acha o checker mesmo já compilado | Caminho relativo resolvido a partir da pasta errada (o script troca de diretório antes de procurar o checker) | Corrigido no `Makefile` — usa caminho absoluto internamente |

Se algo ainda parecer inconsistente: rode primeiro `make checker` e
confirme que `./checker_linux` existe e é executável (`ls -la`), depois
`make test REPO=...` — e sempre confira o bloco de configuração impresso
no início da execução antes de investigar mais fundo.

---

## 📦 Requisitos

- **Bash** (Linux ou macOS)
- **`cc`/`gcc`/`clang`** — para compilar o `checker.c`
- `shuf` — geração de números aleatórios (padrão no Linux; no macOS use
  `brew install coreutils` e `gshuf`, ou adapte o script)
- **Opcional:** `valgrind` (seção 12), `norminette` (seção 1) — se
  ausentes, o script avisa e pula a seção, sem travar

---

## 🔧 Personalização rápida

- Limites de número de operações (100 / 500 números) → seções `9.` e `11.`
  do `.sh`
- Limiares de "aceitável/bom/excelente" → mesmas seções
- Faixa de valores usados no `shuf` → ajuste conforme o enunciado do seu
  campus, se diferente do padrão
- Compilador/flags do checker → variáveis `CC` e `CFLAGS` no topo do
  `Makefile`

---

## 📖 Exemplo de saída

```
==================================================
  CONFIGURAÇÃO DESTA EXECUÇÃO
==================================================
  Repositório avaliado : /home/user/push_swap_aluno
  Binário push_swap    : ./push_swap
  Checker (candidato)  : ./checker_linux  (confirmado/ajustado na seção 2)

==================================================
  RESUMO FINAL
==================================================
  ✔ Compilação
  ✔ Gerenciamento de erros
  ✔ Seleção de estratégia (básico)
  ✔ Entradas já ordenadas
  ✔ Entradas pequenas (3 números)
  ✔ Entradas médias (5 números)
  ✔ Benchmark / desordem
  ✔ Entradas grandes (100 números)
  ✔ Comparação de flags de estratégia
  ✔ Entradas muito grandes (500 números)
  ✔ Vazamentos de memória
  ✔ Robustez / sem crash
  ✔ Checker - gerenciamento de erros
  ✔ Checker - testes falsos
  ✔ Checker - testes corretos

Seções aprovadas: 15 / 15
```

---

## ⚠️ Limitações

- Não substitui a defesa oral: "o aluno sabe explicar o código" e "ambos
  conseguem defender qualquer parte do projeto" exigem interação humana.
- Os limites de operações refletem o enunciado padrão do push_swap; ajuste
  se o seu campus definir valores diferentes.
- A checagem de seções do README (Descrição/Instruções/Recursos) é uma
  convenção opcional própria deste tester, não uma regra oficial da 42 —
  reprovar ali não afeta a nota.

## Author

Jamielly R.
GitHub: https://github.com/Jamielly