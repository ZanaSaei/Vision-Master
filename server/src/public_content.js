'use strict';

/** Return only player-visible challenge data; answer keys never leave storage. */
function publicContentFor(dateKey, gameType, row) {
  const publicContent = row && row.public_content ? row.public_content : {};
  if (gameType !== 'wordef') return publicContent;
  const questions = Array.isArray(publicContent.questions) ? publicContent.questions : [];
  const secretAnswers = Array.isArray(row.secret_content && row.secret_content.answers)
    ? row.secret_content.answers
    : [];
  return {
    ...publicContent,
    questions: questions.map((question, index) => {
      const options = Array.isArray(question.options) ? question.options : [];
      const answer = secretAnswers[index];
      const safePrompt = question.kind === 'meaning' ? question.prompt : '';
      return {
        index: question.index,
        kind: question.kind,
        word: question.word,
        prompt: options.includes(safePrompt) || safePrompt === answer ? '' : safePrompt,
        options,
      };
    }),
  };
}

module.exports = { publicContentFor };
