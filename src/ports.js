const copyContainer = document.getElementById('copy')
const app = Elm.Main.embed(document.querySelector("div"))
const { ports } = app
const notePrefix = 'note-'

function getEmails() {
    try {
        return JSON.parse(localStorage.getItem('emails'))
    } catch (error) {
        // TODO: Should inform Elm?
        return []
    }
}

function storeEmails(emails) {
    try {
        localStorage.setItem('emails', JSON.stringify(emails))
    } catch (error) {
        console.log(error)
        // TODO: Should inform Elm?
    }
}

function noteId(emailId = '') {
    return `${notePrefix}${emailId}`
}

function rawNoteId(id) {
    return id.replace(notePrefix, '')
}

function forNotes(action) {
    const baseNoteId = noteId()
    for (const key of Object.keys(localStorage)) {
        if (key.includes(baseNoteId)) {
            action(key)
        }
    }
}

if (!localStorage.getItem('emails')) {
    storeEmails([])
}

ports.storeEmail.subscribe(email => {
    const emails = getEmails()
    emails.push(email)
    storeEmails(emails)
})

ports.storeNote.subscribe(([emailId, content]) => {
    localStorage.setItem(noteId(emailId), content)
})

ports.removeEmail.subscribe(emailId => {
    storeEmails(getEmails().filter(({ id }) => id !== emailId))
    localStorage.removeItem(noteId(emailId))
})

ports.removeAllEmails.subscribe(() => {
    storeEmails([])
    forNotes(key => localStorage.removeItem(key))
})

ports.getEmails.subscribe(() => {
    ports.receiveEmails.send(getEmails())
})

ports.copy.subscribe(content => {
    const currentActiveElement = document.activeElement
    copyContainer.value = content
    copyContainer.select()
    document.execCommand('copy')
    currentActiveElement.focus()
})

ports.getNotes.subscribe(() => {
    const notes = []
    forNotes(key => notes.push([rawNoteId(key), localStorage.getItem(key)]))
    ports.receiveNotes.send(notes)
})

ports.storeSettings.subscribe(settings => {
    localStorage.setItem('settings', JSON.stringify(settings))
})

ports.getSettings.subscribe(() => {
    const settings = JSON.parse(localStorage.getItem('settings'))
    ports.receiveSettings.send(settings)
})