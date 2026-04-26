import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";

interface StartupData {
  idStartup: number;
  nome: string;
  descricao: string;
  estagioDesenvolvimento: string;
  setor: string;
  cptAportado: number;
  totalTokensEmitidos: number;
  valorToken: number;
  socios: string[];
  participacaoSocietaria: string[];
  membrosConselho: string[];
  linksVideos: string[];
  status: string;
  importadoEm: admin.firestore.FieldValue;
  origemImportacao: string;
}

enum EstagioDesenvolvimento {
  NOVA = "nova",
  EM_OPERACAO = "emOperacao",
  EM_EXPANSAO = "emExpansao",
}

class StartupCsvFirestoreImporter {
  private firestore: admin.firestore.Firestore;
  private collectionName = "startups";

  constructor(firestore: admin.firestore.Firestore) {
    this.firestore = firestore;
  }

  /**
   * Importa startups de um arquivo CSV
   */
  async importarDoArquivo(caminhoArquivo: string): Promise<number> {
    const csvContent = fs.readFileSync(caminhoArquivo, "utf-8");
    return this.importarDoConteudo(csvContent);
  }

  /**
   * Importa startups do conteúdo CSV
   */
  async importarDoConteudo(csvContent: string): Promise<number> {
    const rows = this.parseCsv(csvContent);

    if (rows.length <= 1) {
      return 0;
    }

    const headers = rows[0];
    let batch = this.firestore.batch();
    let operationCount = 0;
    let importedCount = 0;

    for (let i = 1; i < rows.length; i++) {
      const row = rows[i];

      if (this.isRowEmpty(row)) {
        continue;
      }

      const startupData = this.rowToFirestore(headers, row);
      const startupId = startupData.idStartup.toString();
      const document = this.firestore
        .collection(this.collectionName)
        .doc(startupId);

      batch.set(document, startupData, { merge: true });
      operationCount++;
      importedCount++;

      if (operationCount === 400) {
        await batch.commit();
        batch = this.firestore.batch();
        operationCount = 0;
      }
    }

    if (operationCount > 0) {
      await batch.commit();
    }

    return importedCount;
  }

  /**
   * Converte uma linha do CSV para documento Firestore
   */
  private rowToFirestore(
    headers: string[],
    row: string[]
  ): StartupData {
    const valuesByHeader: { [key: string]: string } = {};

    for (let i = 0; i < headers.length; i++) {
      const value = i < row.length ? row[i].trim() : "";
      valuesByHeader[headers[i].trim()] = value;
    }

    const parseDouble = (value?: string): number => {
      if (!value || value.trim() === "") return 0.0;
      const normalized = value.replace(",", ".");
      return parseFloat(normalized) || 0.0;
    };

    const splitList = (rawValue?: string): string[] => {
      if (!rawValue || rawValue.trim() === "") return [];
      return rawValue
        .split(";")
        .map((item) => item.trim())
        .filter((item) => item.length > 0);
    };

    return {
      idStartup: parseInt(valuesByHeader["id_startup"] || "0", 10),
      nome: valuesByHeader["nome_startup"] || "",
      descricao: valuesByHeader["descricao"] || "",
      estagioDesenvolvimento: this.mapEstagio(
        valuesByHeader["estagio"] || ""
      ),
      setor: valuesByHeader["setor"] || "",
      cptAportado: parseDouble(valuesByHeader["capital_aportado"]),
      totalTokensEmitidos: parseInt(
        valuesByHeader["tokens_emitidos"] || "0",
        10
      ),
      valorToken: parseDouble(valuesByHeader["Valor_Token"]),
      socios: splitList(valuesByHeader["socios"]),
      participacaoSocietaria: splitList(
        valuesByHeader["participacao_societaria"]
      ),
      membrosConselho: splitList(valuesByHeader["mentores_conselho"]),
      linksVideos: splitList(valuesByHeader["video_demo"]),
      status: valuesByHeader["status"] || "inativa",
      importadoEm: admin.firestore.FieldValue.serverTimestamp(),
      origemImportacao: "MesclaInvest_StartupList.csv",
    };
  }

  /**
   * Faz parse do conteúdo CSV
   */
  private parseCsv(csvContent: string): string[][] {
    const normalized = csvContent
      .replace(/\r\n/g, "\n")
      .replace(/\r/g, "\n");

    const rows: string[][] = [];
    const currentRow: string[] = [];
    let currentField = "";
    let insideQuotes = false;

    for (let i = 0; i < normalized.length; i++) {
      const char = normalized[i];

      if (char === '"') {
        const nextIsQuote =
          i + 1 < normalized.length && normalized[i + 1] === '"';

        if (insideQuotes && nextIsQuote) {
          currentField += '"';
          i++;
        } else {
          insideQuotes = !insideQuotes;
        }
        continue;
      }

      if (char === "," && !insideQuotes) {
        currentRow.push(currentField);
        currentField = "";
        continue;
      }

      if (char === "\n" && !insideQuotes) {
        currentRow.push(currentField);
        rows.push([...currentRow]);
        currentRow.length = 0;
        currentField = "";
        continue;
      }

      currentField += char;
    }

    if (currentField || currentRow.length > 0) {
      currentRow.push(currentField);
      rows.push([...currentRow]);
    }

    return rows;
  }

  /**
   * Verifica se uma linha está vazia
   */
  private isRowEmpty(row: string[]): boolean {
    return row.every((col) => col.trim().length === 0);
  }

  /**
   * Mapeia o estágio de desenvolvimento
   */
  private mapEstagio(rawValue: string): string {
    const normalized = rawValue.trim().toLowerCase();

    switch (normalized) {
      case "em_operacao":
        return EstagioDesenvolvimento.EM_OPERACAO;
      case "em_expansao":
        return EstagioDesenvolvimento.EM_EXPANSAO;
      case "nova":
      default:
        return EstagioDesenvolvimento.NOVA;
    }
  }
}

export { StartupCsvFirestoreImporter, StartupData, EstagioDesenvolvimento };
