# ============================================================================
#  Makefile — patibum-test
#
#  Compila o checker próprio (checker.c) e roda o push_swap_tester.sh
#  sem precisar de nenhum passo manual (chmod, cc, etc.).
#
#  Uso:
#      make checker              # só compila o checker
#      make test REPO=/caminho   # compila (se preciso) e roda o tester
#      make test                 # assume REPO=. (repo atual)
#      make clean / fclean / re  # limpeza padrão
# ============================================================================

NAME		= checker_linux
CC			= cc
CFLAGS		= -Wall -Wextra -Werror
SRC			= checker.c
TESTER		= push_swap_tester.sh

# Pasta do projeto push_swap a ser avaliado.
# Ex: make test REPO=~/Downloads/Avaliados/push_swap_yann
REPO		?= .

# ---------------------------------------------------------------------------

all: checker

checker: $(NAME)

$(NAME): $(SRC)
	@echo "Compilando checker ($(CFLAGS))..."
	@$(CC) $(CFLAGS) $(SRC) -o $(NAME)
	@chmod +x $(NAME)
	@echo "OK -> ./$(NAME)"

test: checker
	@chmod +x $(TESTER)
	@./$(TESTER) "$(REPO)" ./push_swap ./$(NAME)

clean:
	@rm -f $(NAME)

fclean: clean

re: fclean all

.PHONY: all checker test clean fclean re
