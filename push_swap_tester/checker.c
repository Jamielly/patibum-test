/* ************************************************************************** */
/*                                                                            */
/*  checker.c — checker próprio para push_swap                              */
/*                                                                            */
/*  Uso:                                                                     */
/*      ./checker 2 1 3 4                                                    */
/*      (lê instruções da entrada padrão, uma por linha, até EOF)            */
/*                                                                            */
/*  Instruções aceitas: sa sb ss pa pb ra rb rr rra rrb rrr                  */
/*  Ao encontrar EOF, imprime:                                               */
/*      OK  -> se a pilha a estiver ordenada e a pilha b estiver vazia       */
/*      KO  -> caso contrário                                                */
/*  Em qualquer argumento ou instrução inválida, imprime "Error" e sai(1).   */
/*                                                                            */
/* ************************************************************************** */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <unistd.h>

typedef struct s_node
{
	long			value;
	struct s_node	*next;
}	t_node;

static void	error_exit(void)
{
	write(2, "Error\n", 6);
	exit(1);
}

/* ---------------------------------------------------------------------- */
/* Parsing e validação dos argumentos (mesma régua do push_swap)          */
/* ---------------------------------------------------------------------- */

static long	parse_long(const char *s, int *ok)
{
	long	sign;
	long	res;
	int		i;

	i = 0;
	sign = 1;
	res = 0;
	*ok = 1;
	if (s[i] == '+' || s[i] == '-')
	{
		if (s[i] == '-')
			sign = -1;
		i++;
	}
	if (!s[i])
		*ok = 0;
	while (s[i])
	{
		if (s[i] < '0' || s[i] > '9')
		{
			*ok = 0;
			return (0);
		}
		res = res * 10 + (s[i] - '0');
		if (res * sign > INT_MAX || res * sign < INT_MIN)
		{
			*ok = 0;
			return (0);
		}
		i++;
	}
	return (res * sign);
}

static void	check_duplicates(long *vals, int n)
{
	int	i;
	int	j;

	i = 0;
	while (i < n)
	{
		j = i + 1;
		while (j < n)
		{
			if (vals[i] == vals[j])
				error_exit();
			j++;
		}
		i++;
	}
}

static t_node	*build_stack_a(int argc, char **argv, int *size)
{
	long	*vals;
	t_node	*head;
	t_node	*new;
	int		i;
	int		ok;

	*size = argc - 1;
	if (*size == 0)
		return (NULL);
	vals = malloc(sizeof(long) * (*size));
	if (!vals)
		error_exit();
	i = 0;
	while (i < *size)
	{
		vals[i] = parse_long(argv[i + 1], &ok);
		if (!ok)
		{
			free(vals);
			error_exit();
		}
		i++;
	}
	check_duplicates(vals, *size);
	head = NULL;
	i = *size - 1;
	while (i >= 0)
	{
		new = malloc(sizeof(t_node));
		if (!new)
			error_exit();
		new->value = vals[i];
		new->next = head;
		head = new;
		i--;
	}
	free(vals);
	return (head);
}

/* ---------------------------------------------------------------------- */
/* Operações da pilha (idênticas às do subject)                           */
/* ---------------------------------------------------------------------- */

static void	swap(t_node **stack)
{
	t_node	*first;
	t_node	*second;

	if (!*stack || !(*stack)->next)
		return ;
	first = *stack;
	second = first->next;
	first->next = second->next;
	second->next = first;
	*stack = second;
}

static void	push(t_node **dst, t_node **src)
{
	t_node	*moved;

	if (!*src)
		return ;
	moved = *src;
	*src = (*src)->next;
	moved->next = *dst;
	*dst = moved;
}

static void	rotate(t_node **stack)
{
	t_node	*first;
	t_node	*last;

	if (!*stack || !(*stack)->next)
		return ;
	first = *stack;
	*stack = first->next;
	last = *stack;
	while (last->next)
		last = last->next;
	last->next = first;
	first->next = NULL;
}

static void	rev_rotate(t_node **stack)
{
	t_node	*prev;
	t_node	*cur;

	if (!*stack || !(*stack)->next)
		return ;
	prev = NULL;
	cur = *stack;
	while (cur->next)
	{
		prev = cur;
		cur = cur->next;
	}
	prev->next = NULL;
	cur->next = *stack;
	*stack = cur;
}

/* ---------------------------------------------------------------------- */
/* Leitura das instruções via stdin e execução                            */
/* ---------------------------------------------------------------------- */

static int	exec_instr(char *line, t_node **a, t_node **b)
{
	if (strcmp(line, "sa") == 0)
		swap(a);
	else if (strcmp(line, "sb") == 0)
		swap(b);
	else if (strcmp(line, "ss") == 0)
	{
		swap(a);
		swap(b);
	}
	else if (strcmp(line, "pa") == 0)
		push(a, b);
	else if (strcmp(line, "pb") == 0)
		push(b, a);
	else if (strcmp(line, "ra") == 0)
		rotate(a);
	else if (strcmp(line, "rb") == 0)
		rotate(b);
	else if (strcmp(line, "rr") == 0)
	{
		rotate(a);
		rotate(b);
	}
	else if (strcmp(line, "rra") == 0)
		rev_rotate(a);
	else if (strcmp(line, "rrb") == 0)
		rev_rotate(b);
	else if (strcmp(line, "rrr") == 0)
	{
		rev_rotate(a);
		rev_rotate(b);
	}
	else
		return (0);
	return (1);
}

static void	strip_newline(char *s)
{
	size_t	len;

	len = strlen(s);
	if (len > 0 && s[len - 1] == '\n')
		s[len - 1] = '\0';
}

static void	run_instructions(t_node **a, t_node **b)
{
	char	*line;
	size_t	cap;
	ssize_t	n;

	line = NULL;
	cap = 0;
	while ((n = getline(&line, &cap, stdin)) != -1)
	{
		(void)n;
		strip_newline(line);
		if (line[0] == '\0')
			continue ;
		if (!exec_instr(line, a, b))
		{
			free(line);
			error_exit();
		}
	}
	free(line);
}

static int	is_sorted(t_node *a, t_node *b)
{
	if (b != NULL)
		return (0);
	if (!a)
		return (1);
	while (a->next)
	{
		if (a->value > a->next->value)
			return (0);
		a = a->next;
	}
	return (1);
}

int	main(int argc, char **argv)
{
	t_node	*a;
	t_node	*b;
	int		size;

	b = NULL;
	a = build_stack_a(argc, argv, &size);
	run_instructions(&a, &b);
	if (is_sorted(a, b))
		write(1, "OK\n", 3);
	else
		write(1, "KO\n", 3);
	return (0);
}
