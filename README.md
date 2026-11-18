# Estratégias de alocação para o problema de localização de concentradores com maximização de lucro

Este repositório implementa duas formulações de Programação Linear Inteira Mista (PLIM) para o problema de localização de concentradores (*hubs*) com maximização do lucro. As duas formulações são resolvidas no IBM ILOG CPLEX e avaliadas na instância CAB com diferentes estratégias de alocação (única, $r$-alocação e múltipla).

## O problema

O objetivo é decidir quantos e quais concentradores instalar, quais arcos entre concentradores ativar, quais pares origem-destino (O-D) atender e como rotear cada fluxo atendido, de forma a maximizar o lucro: a receita total menos os custos de transporte e os custos fixos de instalação. As características consideradas são:

- cada nó pode ser alocado a no máximo $r$ concentradores (alocação única com $r = 1$, $r$-alocação com $1 < r < n$ e alocação múltipla com $r = n$);
- o problema é não capacitado;
- a rede de concentradores é incompleta;
- não são permitidas conexões diretas entre nós não concentradores;
- a demanda não precisa ser totalmente atendida;
- há custos fixos de instalação de concentradores e de ativação dos arcos entre eles.

## Formulações

| Formulação | Roteamento | Executável |
|---|---|---|
| **Proposta** (baseada em Oliveira, Sá e Souza, 2022) | variáveis contínuas $a_{ik}$ e $b_{ijm}$, ligadas por conservação de fluxo | `out` |
| **Taherkhani e Alumur (2019)** | variáveis binárias de caminho $y_{ijkm}$ | `taherkhani_out` |

## Estrutura do repositório

```
.
├── model.hpp / model.cpp      # leitura dos dados e construção das duas formulações
│                              #   createVariables / createConstraints            -> formulação proposta
│                              #   createVariablesTaherkhani / createConstraintsTaherkhani -> referência
├── main.cpp                   # formulação proposta: CPLEX, pré-processamento, resolução e saída
├── main-taherkhani.cpp        # formulação de Taherkhani e Alumur (2019): idem
├── cab.txt                    # instância CAB (25 nós)
├── Makefile
└── results/
    ├── my-results/            # resultados da formulação proposta (r1, r2, r3, r25)
    └── taherkhani-results/    # resultados da formulação de referência (r1, r2, r3, r25)
```

## Requisitos

- IBM ILOG CPLEX Optimization Studio 22.1.2 (bibliotecas Concert Technology e CPLEX)
- `g++` com suporte a C++11 ou superior
- Linux x86-64 (os experimentos foram executados no Linux Mint 22.2)

O `Makefile` espera o CPLEX em `/opt/ibm/ILOG/CPLEX_Studio2212`. Se ele estiver instalado em outro caminho, ajuste a variável `ILOG` no início do arquivo.

## Compilação

```bash
make                    # compila as duas formulações
make build-mine         # apenas a formulação proposta        -> ./out
make build-taherkhani   # apenas a formulação de referência   -> ./taherkhani_out
make clean              # remove executáveis e arquivos de resultado
```

## Execução

```bash
./out            <instancia> <alpha> <receita> <custo_hub> <custo_link> [r]
./taherkhani_out <instancia> <alpha> <receita> <custo_hub> <custo_link> [r]
```

| Argumento | Parâmetro | Descrição | Valores usados |
|---|---|---|---|
| `instancia` | — | arquivo da instância | `cab.txt` |
| `alpha` | $\alpha$ | fator de desconto nos arcos entre concentradores ($0 \le \alpha \le 1$) | 0.2, 0.4, 0.6, 0.8 |
| `receita` | $r_{ij}$ | receita por unidade de demanda atendida | 1000, 1500, 2000 |
| `custo_hub` | $s_k$ | custo fixo de instalação de um concentrador | 50, 100, 150 |
| `custo_link` | $g_{km}$ | custo fixo de ativação de um arco entre concentradores | 5, 10, 15 |
| `r` | $r$ | número máximo de concentradores por nó (opcional, padrão `1`) | 1, 2, 3, 25 |

Com `r = 25` (igual a $n$), o limite de alocações deixa de restringir o modelo, o que corresponde à alocação múltipla. Os custos fixos variam em conjunto: (50, 5) baixo, (100, 10) médio e (150, 15) alto.

Exemplos:

```bash
# Formulação proposta, alocação única, receita alta, custos baixos, alpha = 0,2
./out cab.txt 0.2 2000 50 5 1

# Taherkhani e Alumur (2019), alocação múltipla, receita baixa, custos altos, alpha = 0,8
./taherkhani_out cab.txt 0.8 1000 150 15 25
```
Algumas instâncias levam horas. O limite de tempo é de 21600 s (6 h) de relógio por instância.

## Configuração do CPLEX e pré-processamento

- Método: *branch-and-cut* padrão do CPLEX, com o paralelismo padrão (todas as *threads* disponíveis).
- `EpGap = 1e-7` (tolerância de gap relativo) e `TiLim = 21600` (6 h de tempo de relógio), iguais nas duas formulações.
- Antes da resolução, as variáveis de roteamento que nunca seriam lucrativas são fixadas em zero:
  - formulação proposta: $b_{ijm} = 0$ se $r_{ij} < c_{mj}$;
  - formulação de referência: $y_{ijkm} = 0$ se $r_{ij} < c_{ik} + c_{mj}$.

## Dados

A instância CAB (*Civil Aeronautics Board*), introduzida por O'Kelly (1987), representa 25 cidades da rede aérea dos Estados Unidos em 1970. A primeira linha de `cab.txt` contém $n$. Em seguida, para cada par $(i, j)$, há a demanda $w_{ij}$ e o custo unitário de transporte $c_{ij}$. Na leitura, as demandas são normalizadas para que $\sum_{i,j} w_{ij} = 1$.

## Saída

Cada execução imprime um resumo no terminal e acrescenta um bloco ao arquivo de resultados da formulação (`my_results.txt` para a proposta e `taherkhani_results.txt` para a referência):

```
Informações Gerais: cab.txt | 25 | 0.8 | 1000 | 150 | 15 | r = 1
Valor função objetivo: 15.282997
Demanda Satisfeita: 96 pares (16.00%)
Tempo de CPU: 5.810000
Hubs: 17
======================================================================
```

- **Informações Gerais**: instância, $n$, $\alpha$, receita, custo de concentrador, custo de arco e $r$.
- **Valor função objetivo**: lucro ótimo.
- **Demanda Satisfeita**: número e percentual dos $n(n-1) = 600$ pares O-D distintos que recebem fluxo. O indicador conta **pares**, não o volume de demanda.
- **Tempo de CPU**: medido com `IloTimer`, que soma o tempo de todas as *threads*. Por isso, pode ser maior que o tempo de relógio decorrido e até ultrapassar o valor de `TiLim`.
- **Hubs**: concentradores instalados, na numeração da instância CAB (1 a 25).

Os arquivos em `results/` contêm os resultados apresentados no relatório: `r1.txt` corresponde à tabela de alocação única, `r2.txt` à de $r = 2$, e `r3.txt` e `r25.txt` à tabela de $r = 3$ e alocação múltipla.

## Referências

- O'KELLY, M. E. A quadratic integer program for the location of interacting hub facilities. *European Journal of Operational Research*, v. 32, p. 393–404, 1987.
- OLIVEIRA, F. A.; SÁ, E. M.; SOUZA, S. R. Benders decomposition applied to profit maximizing hub location problem with incomplete hub network. *Computers & Operations Research*, v. 142, p. 105715, 2022.
- TAHERKHANI, G.; ALUMUR, S. A. Profit maximizing hub location problems. *Omega*, v. 86, p. 1–15, 2019.