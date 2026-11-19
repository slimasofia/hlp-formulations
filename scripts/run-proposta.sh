#!/usr/bin/env bash
# Executa todas as instâncias CAB da formulação proposta.
#
# Uso (a partir de qualquer diretório):
#   ./scripts/run-proposta.sh            # roda r = 1, 2, 3 e 25 (144 instâncias)
#   ./scripts/run-proposta.sh 1 2        # roda apenas os valores de r informados
#
# Para cada valor de r, são 3 receitas x 3 níveis de custo x 4 valores de alpha = 36 instâncias.
# Os resultados de cada r são gravados em results/my-results/r<r>.txt (ex.: results/my-results/r1.txt).
# ATENÇÃO: o arquivo de cada r executado é sobrescrito no início da execução daquele r.
# Os resultados originais do relatório podem ser recuperados com: git checkout -- results/my-results
#
# Como algumas instâncias levam horas, recomenda-se rodar em segundo plano, por exemplo:
#   nohup ./scripts/run-proposta.sh > run-proposta.log 2>&1 &

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BIN="$ROOT/out"
INSTANCIA="data/cab.txt"
SAIDA_PROGRAMA="my_results.txt"        # arquivo que o executável grava no diretório corrente
DIR_RESULTADOS="results/my-results"

if [ ! -x "$BIN" ]; then
    echo "Executável ./out não encontrado. Compile antes com: make build-mine" >&2
    exit 1
fi
if [ ! -f "$INSTANCIA" ]; then
    echo "Instância $INSTANCIA não encontrada." >&2
    exit 1
fi
mkdir -p "$DIR_RESULTADOS"

# Cada instância roda num diretório temporário, para que o arquivo de saída do executável
# (e o log do CPLEX) não se misture com outras execuções. A instância é ligada como
# data/cab.txt para que o nome registrado nos resultados continue o mesmo.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/data"
ln -s "$ROOT/$INSTANCIA" "$TMP/$INSTANCIA"

if [ "$#" -gt 0 ]; then
    R_VALUES=("$@")
else
    R_VALUES=(1 2 3 25)
fi

RECEITAS=(2000 1500 1000)                 # alta, média, baixa
CUSTOS=("50 5" "100 10" "150 15")         # (custo_hub custo_link): baixo, médio, alto
ALPHAS=(0.2 0.4 0.6 0.8)

total=$(( ${#R_VALUES[@]} * ${#RECEITAS[@]} * ${#CUSTOS[@]} * ${#ALPHAS[@]} ))
k=0
falhas=0

for r in "${R_VALUES[@]}"; do
    destino="$DIR_RESULTADOS/r$r.txt"
    : > "$destino"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Iniciando r=$r -> $destino"

    for receita in "${RECEITAS[@]}"; do
        for custo in "${CUSTOS[@]}"; do
            read -r custo_hub custo_link <<< "$custo"
            for alpha in "${ALPHAS[@]}"; do
                k=$((k + 1))
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ($k/$total) r=$r receita=$receita custo_hub=$custo_hub custo_link=$custo_link alpha=$alpha"

                rm -f "$TMP/$SAIDA_PROGRAMA"
                if ! (cd "$TMP" && "$BIN" "$INSTANCIA" "$alpha" "$receita" "$custo_hub" "$custo_link" "$r"); then
                    echo "  ERRO na instância acima; seguindo para a próxima." >&2
                    falhas=$((falhas + 1))
                fi
                if [ -f "$TMP/$SAIDA_PROGRAMA" ]; then
                    cat "$TMP/$SAIDA_PROGRAMA" >> "$destino"
                fi
            done
        done
    done
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Concluído: $total instâncias ($falhas com erro). Resultados em $DIR_RESULTADOS/"
