#!/bin/bash
###############################################################################
#  PUSH_SWAP TESTER — baseado na régua de avaliação 42
#
#  Uso:
#     ./push_swap_tester.sh [caminho_do_repo] [push_swap_bin] [checker_bin]
#
#  Exemplos:
#     ./push_swap_tester.sh                     # assume diretório atual
#     ./push_swap_tester.sh ~/push_swap
#     ./push_swap_tester.sh . ./push_swap ./checker_linux
#
#  Requisitos opcionais: valgrind (leak check), norminette (norma)
###############################################################################

set -u

# ------------------------------------------------------------------------- #
# CONFIGURAÇÃO
# ------------------------------------------------------------------------- #
REPO_DIR="${1:-.}"
cd "$REPO_DIR" || { echo "Diretório não encontrado: $REPO_DIR"; exit 1; }

PUSH_SWAP="${2:-./push_swap}"

# Detecta o checker correto conforme o SO, se não foi passado explicitamente
if [ -n "${3:-}" ]; then
    CHECKER="$3"
else
    OS="$(uname -s)"
    if [ "$OS" = "Darwin" ]; then
        CHECKER="./checker_Mac"
    elif [ -f ./fedora_checker ] && grep -qi fedora /etc/os-release 2>/dev/null; then
        CHECKER="./fedora_checker"
    else
        CHECKER="./checker_linux"
    fi
fi

# Cores
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

TOTAL_SECTIONS=0
PASSED_SECTIONS=0
FATAL=0
CHECKER_MISSING=0

declare -A SECTION_RESULT

# ------------------------------------------------------------------------- #
# HELPERS
# ------------------------------------------------------------------------- #
header() {
    echo -e "\n${BLUE}${BOLD}==================================================${NC}"
    echo -e "${BLUE}${BOLD}  $1${NC}"
    echo -e "${BLUE}${BOLD}==================================================${NC}"
}

subtest() {
    # $1 = descrição   $2 = resultado (0=ok,1=fail)
    if [ "$2" -eq 0 ]; then
        echo -e "  ${GREEN}[OK]${NC} $1"
    else
        echo -e "  ${RED}[KO]${NC} $1"
    fi
}

info()  { echo -e "  ${YELLOW}[i]${NC} $1"; }
fatal() { echo -e "${RED}${BOLD}[FATAL] $1${NC}"; FATAL=1; }
warn_checker() { echo -e "${YELLOW}${BOLD}[AVISO] $1${NC}"; CHECKER_MISSING=1; }

section_score() {
    # $1 = nome  $2 = passou(0/1)
    TOTAL_SECTIONS=$((TOTAL_SECTIONS+1))
    if [ "$2" -eq 0 ]; then
        PASSED_SECTIONS=$((PASSED_SECTIONS+1))
        SECTION_RESULT["$1"]="PASS"
    else
        SECTION_RESULT["$1"]="FAIL"
    fi
}

# conta instruções produzidas pelo push_swap para um dado argumento
count_ops() {
    echo "$($PUSH_SWAP $1 2>/dev/null | wc -l | tr -d ' ')"
}

# roda push_swap | checker e retorna "OK"/"KO"/"SEM_BINARIO"/"SEM_CHECKER"
run_checker() {
    local args="$1"
    if [ ! -x "$PUSH_SWAP" ]; then echo "SEM_BINARIO"; return; fi
    if [ ! -x "$CHECKER" ]; then echo "SEM_CHECKER"; return; fi
    $PUSH_SWAP $args 2>/dev/null | $CHECKER $args 2>/dev/null | tail -1
}

check_no_segfault() {
    # $1 = comando completo a ser avaliado com timeout
    local cmd="$1"
    timeout 5 bash -c "$cmd" >/dev/null 2>&1
    local rc=$?
    if [ $rc -eq 139 ] || [ $rc -eq 134 ] || [ $rc -eq 138 ]; then
        return 1
    fi
    return 0
}

is_sorted_stdout_empty() {
    # verifica se não produziu nenhuma saída (entrada já ordenada)
    local out
    out=$($PUSH_SWAP "$@" 2>/dev/null)
    [ -z "$out" ]
}

# ------------------------------------------------------------------------- #
# 0. PRÉ-CHECAGENS
# ------------------------------------------------------------------------- #
header "0. PRÉ-CHECAGENS"

if [ ! -f "$PUSH_SWAP" ] && [ ! -f "Makefile" ]; then
    fatal "Nenhum Makefile encontrado em $REPO_DIR — abortando."
fi

if [ -f "README.md" ]; then
    subtest "README.md presente" 0
    FIRST_LINE=$(head -n1 README.md)
    if echo "$FIRST_LINE" | grep -qiE "(this project has been created as part of the 42 curriculum by|esta atividade foi criada como parte do currículo 42 por)"; then
        subtest "Primeira linha do README no formato esperado" 0
    else
        subtest "Primeira linha do README no formato esperado (encontrado: '$FIRST_LINE')" 1
    fi
    for sec in "Description" "Instructions" "Resources"; do
        if grep -qi "$sec" README.md; then
            subtest "Seção '$sec' presente no README" 0
        else
            subtest "Seção '$sec' presente no README" 1
        fi
    done
else
    subtest "README.md presente" 1
fi

NUM_CONTRIBUTORS="?"
if [ -d .git ]; then
    NUM_CONTRIBUTORS=$(git log --format='%ae' 2>/dev/null | sort -u | wc -l | tr -d ' ')
    info "Autores distintos detectados no git log: $NUM_CONTRIBUTORS (confirme manualmente = 2 alunos)"
fi

# ------------------------------------------------------------------------- #
# 1. NORMINETTE
# ------------------------------------------------------------------------- #
header "1. NORMINETTE"
if command -v norminette >/dev/null 2>&1; then
    NORM_OUT=$(norminette $(find . -maxdepth 3 -name "*.c" -o -name "*.h") 2>/dev/null)
    if echo "$NORM_OUT" | grep -qi "Error"; then
        echo "$NORM_OUT" | grep -i "Error" | head -20
        subtest "Norminette sem erros" 1
        section_score "Norminette" 1
    else
        subtest "Norminette sem erros" 0
        section_score "Norminette" 0
    fi
else
    info "norminette não instalado — pule esta seção manualmente."
fi

# ------------------------------------------------------------------------- #
# 2. COMPILAÇÃO
# ------------------------------------------------------------------------- #
header "2. COMPILAÇÃO"
COMPILE_OK=0

if [ -f Makefile ]; then
    for rule in NAME all clean fclean re; do
        if grep -qE "^${rule}[[:space:]]*:" Makefile || grep -q "$rule" Makefile; then
            subtest "Regra '$rule' presente no Makefile" 0
        else
            subtest "Regra '$rule' presente no Makefile" 1
            COMPILE_OK=1
        fi
    done

    if grep -qE "\-Wall" Makefile && grep -qE "\-Wextra" Makefile && grep -qE "\-Werror" Makefile; then
        subtest "Flags -Wall -Wextra -Werror presentes" 0
    else
        subtest "Flags -Wall -Wextra -Werror presentes" 1
        COMPILE_OK=1
    fi

    make fclean >/dev/null 2>&1
    make > /tmp/make_out.log 2>&1
    if [ -f push_swap ]; then
        subtest "make gera o executável push_swap" 0
    else
        subtest "make gera o executável push_swap" 1
        COMPILE_OK=1
        cat /tmp/make_out.log
    fi

    # relink check: segunda chamada a make não deve recompilar nada
    make > /tmp/make_relink.log 2>&1
    if grep -qE "cc |gcc |clang " /tmp/make_relink.log; then
        subtest "make não recompila (sem relink)" 1
        COMPILE_OK=1
    else
        subtest "make não recompila (sem relink)" 0
    fi

    make clean >/dev/null 2>&1
    subtest "make clean executa sem erro" $?

    make fclean >/dev/null 2>&1
    if [ ! -f push_swap ]; then
        subtest "make fclean remove o executável" 0
    else
        subtest "make fclean remove o executável" 1
        COMPILE_OK=1
    fi

    make re > /tmp/make_re.log 2>&1
    if [ -f push_swap ]; then
        subtest "make re recompila corretamente" 0
    else
        subtest "make re recompila corretamente" 1
        COMPILE_OK=1
        cat /tmp/make_re.log
    fi
else
    fatal "Makefile não encontrado"
    COMPILE_OK=1
fi

section_score "Compilação" $COMPILE_OK

SKIP_FUNCTIONAL=0
if [ ! -x "$PUSH_SWAP" ] && [ -f "$PUSH_SWAP" ]; then
    chmod +x "$PUSH_SWAP" 2>/dev/null
fi
if [ ! -x "$PUSH_SWAP" ]; then
    fatal "Executável push_swap não encontrado/gerado ($PUSH_SWAP)."
    echo -e "${YELLOW}${BOLD}As seções seguintes que dependem do binário serão marcadas como PULADAS, mas o script continua até o resumo final.${NC}"
    SKIP_FUNCTIONAL=1
fi

SKIP_CHECKER=0
if [ ! -x "$CHECKER" ] && [ -f "$CHECKER" ]; then
    info "Checker '$CHECKER' encontrado mas sem permissão de execução — aplicando chmod +x..."
    chmod +x "$CHECKER" 2>/dev/null
fi
if [ ! -x "$CHECKER" ]; then
    info "Checker '$CHECKER' não encontrado/sem permissão de execução — tentando localizar alternativa..."
    for c in ./checker_linux ./checker_Mac ./fedora_checker ./checker; do
        if [ -f "$c" ] && [ ! -x "$c" ]; then
            chmod +x "$c" 2>/dev/null
        fi
        if [ -x "$c" ]; then CHECKER="$c"; break; fi
    done
    if [ ! -x "$CHECKER" ]; then
        warn_checker "Nenhum binário checker executável encontrado no diretório testado ($REPO_DIR)."
        echo -e "${YELLOW}${BOLD}Copie o checker do seu campus (checker_linux/checker_Mac/fedora_checker) para dentro dessa pasta antes de rodar o script — sem ele, todas as seções de corretude ficam impossíveis de validar.${NC}"
        SKIP_CHECKER=1
    else
        info "Usando checker: $CHECKER (permissão de execução corrigida automaticamente)"
    fi
else
    info "Usando checker: $CHECKER"
fi

if [ "$SKIP_FUNCTIONAL" -eq 1 ]; then
    for sec in "Gerenciamento de erros" "Seleção de estratégia (básico)" "Entradas já ordenadas" \
               "Entradas pequenas (3 números)" "Entradas médias (5 números)" "Benchmark / desordem" \
               "Entradas grandes (100 números)" "Comparação de flags de estratégia" \
               "Entradas muito grandes (500 números)" "Vazamentos de memória" "Robustez / sem crash"; do
        header "${sec^^}"
        info "Pulada — sem binário push_swap executável."
        section_score "$sec" 1
    done
else

# ------------------------------------------------------------------------- #
# 3. GERENCIAMENTO DE ERROS (push_swap)
# ------------------------------------------------------------------------- #
header "3. GERENCIAMENTO DE ERROS — push_swap"
ERR_PASS=0; ERR_TOTAL=4

out=$($PUSH_SWAP abc def 2>&1 1>/dev/null)
if echo "$out" | grep -qi "error"; then subtest "Parâmetros não numéricos -> Error" 0; ERR_PASS=$((ERR_PASS+1))
else subtest "Parâmetros não numéricos -> Error" 1; fi

out=$($PUSH_SWAP 1 2 2 2>&1 1>/dev/null)
if echo "$out" | grep -qi "error"; then subtest "Número duplicado -> Error" 0; ERR_PASS=$((ERR_PASS+1))
else subtest "Número duplicado -> Error" 1; fi

out=$($PUSH_SWAP 1 2 99999999999999 2>&1 1>/dev/null)
if echo "$out" | grep -qi "error"; then subtest "Overflow (> MAXINT) -> Error" 0; ERR_PASS=$((ERR_PASS+1))
else subtest "Overflow (> MAXINT) -> Error" 1; fi

out=$($PUSH_SWAP 2>&1)
if [ -z "$out" ]; then subtest "Sem parâmetros -> nenhuma saída" 0; ERR_PASS=$((ERR_PASS+1))
else subtest "Sem parâmetros -> nenhuma saída (obteve: '$out')" 1; fi

info "Passou $ERR_PASS/$ERR_TOTAL (mínimo exigido: 3/4)"
[ $ERR_PASS -ge 3 ]; section_score "Gerenciamento de erros" $?

# ------------------------------------------------------------------------- #
# 4. SELEÇÃO DE ESTRATÉGIA — TESTES BÁSICOS
# ------------------------------------------------------------------------- #
header "4. SELEÇÃO DE ESTRATÉGIA — BÁSICO"
STRAT_PASS=0; STRAT_TOTAL=5

for flag in --simple --medium --complex --adaptive; do
    res=$(run_checker "$flag 5 4 3 2 1")
    if [ "$res" = "OK" ]; then subtest "$flag 5 4 3 2 1 -> checker OK" 0; STRAT_PASS=$((STRAT_PASS+1))
    else subtest "$flag 5 4 3 2 1 -> checker OK (obteve '$res')" 1; fi
done

res=$(run_checker "5 4 3 2 1")
if [ "$res" = "OK" ]; then subtest "Sem flag (default --adaptive) -> checker OK" 0; STRAT_PASS=$((STRAT_PASS+1))
else subtest "Sem flag (default --adaptive) -> checker OK (obteve '$res')" 1; fi

info "Passou $STRAT_PASS/$STRAT_TOTAL (mínimo exigido: 3/5)"
[ $STRAT_PASS -ge 3 ]; section_score "Seleção de estratégia (básico)" $?

# ------------------------------------------------------------------------- #
# 5. ENTRADAS JÁ ORDENADAS
# ------------------------------------------------------------------------- #
header "5. ENTRADAS JÁ ORDENADAS (IDENTIDADE)"
SORTED_PASS=0; SORTED_TOTAL=4

for args in "42" "2 3" "0 1 2 3" "0 1 2 3 4 5 6 7 8 9"; do
    if is_sorted_stdout_empty $args; then
        subtest "push_swap $args -> sem saída" 0
        SORTED_PASS=$((SORTED_PASS+1))
    else
        subtest "push_swap $args -> sem saída" 1
    fi
done

info "Passou $SORTED_PASS/$SORTED_TOTAL (mínimo exigido: 3/4)"
[ $SORTED_PASS -ge 3 ]; section_score "Entradas já ordenadas" $?

# ------------------------------------------------------------------------- #
# 6. ENTRADAS PEQUENAS (3 NÚMEROS)
# ------------------------------------------------------------------------- #
header "6. ENTRADAS PEQUENAS (3 NÚMEROS)"
SMALL_OK=0
for args in "2 1 0" "0 2 1" "1 0 2"; do
    res=$(run_checker "$args")
    ops=$(count_ops "$args")
    if [ "$res" = "OK" ]; then
        rating="aceitável"
        [ "$ops" -le 3 ] 2>/dev/null && rating="bom"
        subtest "'$args' -> checker OK, $ops instruções ($rating)" 0
    else
        subtest "'$args' -> checker OK ($res, $ops instruções)" 1
        SMALL_OK=1
    fi
done
section_score "Entradas pequenas (3 números)" $SMALL_OK

# ------------------------------------------------------------------------- #
# 7. ENTRADAS MÉDIAS (5 NÚMEROS)
# ------------------------------------------------------------------------- #
header "7. ENTRADAS MÉDIAS (5 NÚMEROS)"
MED_OK=0
for args in "1 5 2 4 3" "5 1 4 2 3" "3 5 1 4 2"; do
    res=$(run_checker "$args")
    ops=$(count_ops "$args")
    if [ "$res" = "OK" ]; then
        rating="aceitável"
        [ "$ops" -le 12 ] 2>/dev/null && rating="bom"
        subtest "'$args' -> checker OK, $ops instruções ($rating)" 0
    else
        subtest "'$args' -> checker OK ($res, $ops instruções)" 1
        MED_OK=1
    fi
done
section_score "Entradas médias (5 números)" $MED_OK

# ------------------------------------------------------------------------- #
# 8. MODO BENCHMARK
# ------------------------------------------------------------------------- #
header "8. MODO BENCHMARK / CÁLCULO DE DESORDEM"
BENCH_OK=0

out=$($PUSH_SWAP --bench --simple 5 4 3 2 1 2>/dev/null)
if [ -n "$out" ]; then subtest "--bench --simple produz saída de ordenação" 0
else subtest "--bench --simple produz saída de ordenação" 1; BENCH_OK=1; fi

bench_stats=$($PUSH_SWAP --bench --simple 5 4 3 2 1 2>&1 1>/dev/null)
for kw in "%" ; do
    if echo "$bench_stats" | grep -q "$kw"; then subtest "Relatório de benchmark contém percentual de desordem" 0
    else subtest "Relatório de benchmark contém percentual de desordem" 1; BENCH_OK=1; fi
    break
done
info "Saída de estatísticas do benchmark:"
echo "$bench_stats" | sed 's/^/      /'

d_sorted=$($PUSH_SWAP --bench --simple 1 2 3 4 5 2>&1 1>/dev/null | grep -oE "[0-9]+([.,][0-9]+)?%" | head -1)
d_reversed=$($PUSH_SWAP --bench --simple 5 4 3 2 1 2>&1 1>/dev/null | grep -oE "[0-9]+([.,][0-9]+)?%" | head -1)
info "Desordem entrada ordenada (esperado ~0%): $d_sorted"
info "Desordem entrada inversa (esperado ~100%): $d_reversed"

section_score "Benchmark / desordem" $BENCH_OK

# ------------------------------------------------------------------------- #
# 9. ENTRADAS GRANDES (100 NÚMEROS)
# ------------------------------------------------------------------------- #
header "9. ENTRADAS GRANDES (100 NÚMEROS)"
BIG_OK=0
for i in 1 2 3; do
    ARG=$(shuf -i 1-500 -n 100 | tr '\n' ' ')
    res=$(run_checker "$ARG")
    ops=$(count_ops "$ARG")
    if [ "$res" = "OK" ] && [ "$ops" -lt 2000 ] 2>/dev/null; then
        rating="aceitável"
        [ "$ops" -lt 1500 ] 2>/dev/null && rating="bom"
        [ "$ops" -lt 700 ] 2>/dev/null && rating="excelente"
        subtest "Rodada $i: checker OK, $ops instruções ($rating)" 0
    else
        subtest "Rodada $i: checker=$res, $ops instruções (limite 2000)" 1
        BIG_OK=1
    fi
done
section_score "Entradas grandes (100 números)" $BIG_OK

# ------------------------------------------------------------------------- #
# 10. COMPARAÇÃO DE FLAGS DE ESTRATÉGIA (50 números)
# ------------------------------------------------------------------------- #
header "10. COMPARAÇÃO DE FLAGS (50 NÚMEROS)"
ARG=$(shuf -i 1-200 -n 50 | tr '\n' ' ')
declare -A OPS_BY_FLAG
FLAG_OK=0
for flag in --simple --medium --complex --adaptive; do
    res=$(run_checker "$flag $ARG")
    ops=$(count_ops "$flag $ARG")
    OPS_BY_FLAG[$flag]=$ops
    if [ "$res" = "OK" ]; then subtest "$flag -> checker OK, $ops instruções" 0
    else subtest "$flag -> checker OK ($res)" 1; FLAG_OK=1; fi
done
if [ "${OPS_BY_FLAG[--complex]:-999999}" -lt "${OPS_BY_FLAG[--simple]:-0}" ] 2>/dev/null; then
    subtest "--complex usa menos instruções que --simple (${OPS_BY_FLAG[--complex]} < ${OPS_BY_FLAG[--simple]})" 0
else
    subtest "--complex usa menos instruções que --simple (${OPS_BY_FLAG[--complex]:-?} vs ${OPS_BY_FLAG[--simple]:-?})" 1
fi
section_score "Comparação de flags de estratégia" $FLAG_OK

# ------------------------------------------------------------------------- #
# 11. ENTRADAS MUITO GRANDES (500 NÚMEROS)
# ------------------------------------------------------------------------- #
header "11. ENTRADAS MUITO GRANDES (500 NÚMEROS)"
HUGE_OK=0
for i in 1 2; do
    ARG=$(shuf -i 1-1000 -n 500 | tr '\n' ' ')
    res=$(run_checker "$ARG")
    ops=$(count_ops "$ARG")
    if [ "$res" = "OK" ] && [ "$ops" -lt 12000 ] 2>/dev/null; then
        rating="aceitável"
        [ "$ops" -lt 8000 ] 2>/dev/null && rating="bom"
        [ "$ops" -lt 5500 ] 2>/dev/null && rating="excelente"
        subtest "Rodada $i: checker OK, $ops instruções ($rating)" 0
    else
        subtest "Rodada $i: checker=$res, $ops instruções (limite 12000)" 1
        HUGE_OK=1
    fi
done
section_score "Entradas muito grandes (500 números)" $HUGE_OK

# ------------------------------------------------------------------------- #
# 12. VERIFICAÇÃO DE VAZAMENTOS DE MEMÓRIA (push_swap)
# ------------------------------------------------------------------------- #
header "12. VAZAMENTOS DE MEMÓRIA — push_swap"
LEAK_OK=0
if command -v valgrind >/dev/null 2>&1; then
    ARG=$(shuf -i 1-500 -n 100 | tr '\n' ' ')
    VOUT=$(valgrind --leak-check=full --error-exitcode=42 $PUSH_SWAP $ARG 2>&1 1>/dev/null)
    if echo "$VOUT" | grep -q "definitely lost: 0 bytes" && ! echo "$VOUT" | grep -q "Invalid"; then
        subtest "Sem vazamentos definitivos / acessos inválidos (valgrind)" 0
    else
        subtest "Sem vazamentos definitivos / acessos inválidos (valgrind)" 1
        LEAK_OK=1
        echo "$VOUT" | grep -E "lost|Invalid" | sed 's/^/      /'
    fi
else
    info "valgrind não instalado — tente 'leaks' (macOS) ou instale valgrind manualmente."
fi
section_score "Vazamentos de memória" $LEAK_OK

# ------------------------------------------------------------------------- #
# 13. ROBUSTEZ / SEM SEGFAULT (checagem geral)
# ------------------------------------------------------------------------- #
header "13. ROBUSTEZ (SEM SEGFAULT/CRASH)"
CRASH_OK=0
crash_cases=("" "1" "1 1" "a b c" "99999999999999999999" "-- 1 2 3" "--simple --medium 1 2 3")
for c in "${crash_cases[@]}"; do
    if check_no_segfault "$PUSH_SWAP $c"; then
        subtest "push_swap $c -> sem crash" 0
    else
        subtest "push_swap $c -> CRASH DETECTADO" 1
        CRASH_OK=1
    fi
done
section_score "Robustez / sem crash" $CRASH_OK
fi

# ------------------------------------------------------------------------- #
# 14. PROGRAMA CHECKER — GERENCIAMENTO DE ERROS
# ------------------------------------------------------------------------- #
header "14. CHECKER — GERENCIAMENTO DE ERROS"
if [ "$SKIP_CHECKER" -eq 1 ]; then
    info "Pulada — checker não encontrado. Coloque o binário do checker na pasta do projeto."
    section_score "Checker - gerenciamento de erros" 1
else
CHK_ERR_PASS=0

out=$($CHECKER abc def 2>&1 1>/dev/null)
echo "$out" | grep -qi "error"; subtest "Checker: parâmetros não numéricos -> Error" $?
[ $? -eq 0 ] && CHK_ERR_PASS=$((CHK_ERR_PASS+1))

out=$($CHECKER 1 2 2 2>&1 1>/dev/null)
echo "$out" | grep -qi "error"; r=$?; subtest "Checker: número duplicado -> Error" $r
[ $r -eq 0 ] && CHK_ERR_PASS=$((CHK_ERR_PASS+1))

out=$($CHECKER 1 2 99999999999999 2>&1 1>/dev/null)
echo "$out" | grep -qi "error"; r=$?; subtest "Checker: overflow -> Error" $r
[ $r -eq 0 ] && CHK_ERR_PASS=$((CHK_ERR_PASS+1))

out=$($CHECKER < /dev/null 2>&1)
[ -z "$out" ]; r=$?; subtest "Checker: sem parâmetros -> sem saída" $r
[ $r -eq 0 ] && CHK_ERR_PASS=$((CHK_ERR_PASS+1))

out=$(echo "sa
xx
rrr" | $CHECKER 1 2 3 2>&1 1>/dev/null)
echo "$out" | grep -qi "error"; r=$?; subtest "Checker: ação inexistente -> Error" $r
[ $r -eq 0 ] && CHK_ERR_PASS=$((CHK_ERR_PASS+1))

out=$(printf ' sa \nrrr\n' | $CHECKER 1 2 3 2>&1 1>/dev/null)
echo "$out" | grep -qi "error"; r=$?; subtest "Checker: espaços extras na ação -> Error" $r
[ $r -eq 0 ] && CHK_ERR_PASS=$((CHK_ERR_PASS+1))

info "Nota: se pelo menos 1 destes falhar, a régua manda zerar a seção inteira."
[ $CHK_ERR_PASS -eq 6 ]; section_score "Checker - gerenciamento de erros" $?
fi

# ------------------------------------------------------------------------- #
# 15. PROGRAMA CHECKER — TESTES FALSOS (deve dar KO)
# ------------------------------------------------------------------------- #
header "15. CHECKER — TESTES FALSOS (esperado KO)"
if [ "$SKIP_CHECKER" -eq 1 ]; then
    info "Pulada — checker não encontrado."
    section_score "Checker - testes falsos" 1
else
CHK_FALSE_OK=0

res=$(printf 'sa\npb\nrrr\n' | $CHECKER 0 9 1 8 2 7 3 6 4 5 2>/dev/null | tail -1)
if [ "$res" = "KO" ]; then subtest "[sa,pb,rrr] não ordena -> KO" 0
else subtest "[sa,pb,rrr] não ordena -> KO (obteve '$res')" 1; CHK_FALSE_OK=1; fi

res=$(printf 'sa\nsa\nsa\n' | $CHECKER 3 1 2 4 5 2>/dev/null | tail -1)
if [ "$res" = "KO" ]; then subtest "Instruções aleatórias inválidas -> KO" 0
else subtest "Instruções aleatórias inválidas -> KO (obteve '$res')" 1; CHK_FALSE_OK=1; fi

section_score "Checker - testes falsos" $CHK_FALSE_OK
fi

# ------------------------------------------------------------------------- #
# 16. PROGRAMA CHECKER — TESTES CORRETOS (deve dar OK)
# ------------------------------------------------------------------------- #
header "16. CHECKER — TESTES CORRETOS (esperado OK)"
if [ "$SKIP_CHECKER" -eq 1 ]; then
    info "Pulada — checker não encontrado."
    section_score "Checker - testes corretos" 1
else
CHK_TRUE_OK=0

res=$(printf '' | $CHECKER 0 1 2 2>/dev/null | tail -1)
if [ "$res" = "OK" ]; then subtest "Já ordenado, sem instruções -> OK" 0
else subtest "Já ordenado, sem instruções -> OK (obteve '$res')" 1; CHK_TRUE_OK=1; fi

res=$(printf 'pb\nra\npb\nra\nsa\nra\npa\npa\n' | $CHECKER 0 9 1 8 2 2>/dev/null | tail -1)
if [ "$res" = "OK" ]; then subtest "[pb,ra,pb,ra,sa,ra,pa,pa] ordena -> OK" 0
else subtest "[pb,ra,pb,ra,sa,ra,pa,pa] ordena -> OK (obteve '$res')" 1; CHK_TRUE_OK=1; fi

if [ "$SKIP_FUNCTIONAL" -eq 0 ]; then
    RAND_ARG=$(shuf -i 1-100 -n 10 | tr '\n' ' ')
    RAND_INSTR=$($PUSH_SWAP $RAND_ARG 2>/dev/null)
    res=$(echo "$RAND_INSTR" | $CHECKER $RAND_ARG 2>/dev/null | tail -1)
    if [ "$res" = "OK" ]; then subtest "Instruções reais do push_swap ordenam -> OK" 0
    else subtest "Instruções reais do push_swap ordenam -> OK (obteve '$res')" 1; CHK_TRUE_OK=1; fi
fi

section_score "Checker - testes corretos" $CHK_TRUE_OK
fi

# ------------------------------------------------------------------------- #
# RESUMO FINAL
# ------------------------------------------------------------------------- #
header "RESUMO FINAL"
for k in "${!SECTION_RESULT[@]}"; do
    if [ "${SECTION_RESULT[$k]}" = "PASS" ]; then
        echo -e "  ${GREEN}✔${NC} $k"
    else
        echo -e "  ${RED}✘${NC} $k"
    fi
done
echo ""
echo -e "${BOLD}Seções aprovadas: $PASSED_SECTIONS / $TOTAL_SECTIONS${NC}"

if [ $FATAL -eq 1 ]; then
    echo -e "${RED}${BOLD}Houve falha(s) fatal(is) de compilação/executável. Nota final tende a 0 conforme régua.${NC}"
elif [ $CHECKER_MISSING -eq 1 ]; then
    echo -e "${YELLOW}${BOLD}Compilação e binário OK, mas o checker não foi encontrado — as seções de corretude (4, 6, 7, 9, 10, 11, 14, 15, 16) não puderam ser validadas. Coloque o checker na pasta e rode de novo antes de tirar conclusões sobre a nota.${NC}"
fi

echo ""
echo -e "${YELLOW}Lembretes manuais da régua (não automatizáveis por script):${NC}"
echo "  - Confirmar que exatamente 2 alunos estão listados como contribuidores."
echo "  - Confirmar que ambos os alunos sabem explicar TODO o código (não só sua parte)."
echo "  - Confirmar contribuições de cada aluno documentadas no README.md."
echo "  - Pedir explicação dos algoritmos: --simple O(n²), --medium O(n√n), --complex O(n log n), --adaptive."
echo "  - Exercício ao vivo: adicionar flag --count-only em até 10 minutos."
echo "  - Bônus só é avaliado se a parte obrigatória for PERFEITA."
