const typo = new Typo('en_US', false, false, {
    dictionaryPath: 'https://unpkg.com/typo-js@1.2.3/dictionaries'
});
typo.dictionary['roomfinder'] = 1;
typo.dictionary['wifi'] = 1;
typo.dictionary['appartment'] = 1;
typo.dictionary['condo'] = 1;
typo.dictionary['sublease'] = 1;
typo.dictionary['negoitator'] = 1;

function autocorrectInput(input) {
    if (typeof input !== 'string' || !input) return input;
    const words = input.split(' ');
    const correctedWords = words.map(word => {
        if (typo.check(word)) return word;
        const suggestions = typo.suggest(word);
        console.log(`Autocorrect: ${word} -> ${suggestions.length > 0 ? suggestions[0] : word}`);
        return suggestions.length > 0 ? suggestions[0] : word;
    });
    return correctedWords.join(' ');
}

function sanitizeInput(input) {
    if (typeof input !== 'string') return '';
    return input.replace(/[^a-zA-Z0-9\s,.-]/g, '').trim();
}

export { autocorrectInput, sanitizeInput };