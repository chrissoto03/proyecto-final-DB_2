/* Progressive enhancement: split local date/time without changing the submitted
   SQL value until the operator edits it. In particular preserve milliseconds. */
(() => {
  const dates = [...document.querySelectorAll('input[type="datetime-local"]')];
  dates.forEach(original => {
    const parent = original.parentElement;
    const mainLabel = document.querySelector(`label[for="${original.id}"]`);
    const title = mainLabel?.textContent.trim() || 'Horario';
    const group = document.createElement('div'); group.className = 'date-time-picker';
    const day = document.createElement('input'); day.type = 'date'; day.id = original.id + '_date';
    const time = document.createElement('input'); time.type = 'time'; time.id = original.id + '_time'; time.step = '60';
    const dateLabel = document.createElement('label'); dateLabel.htmlFor = day.id; dateLabel.textContent = 'Fecha'; dateLabel.append(day);
    const timeLabel = document.createElement('label'); timeLabel.htmlFor = time.id; timeLabel.textContent = 'Hora'; timeLabel.append(time);
    day.setAttribute('aria-label', title + ': fecha'); time.setAttribute('aria-label', title + ': hora');
    day.required = true; time.required = true;
    day.value = original.value.slice(0,10); time.value = original.value.slice(11,16);
    const summary = document.createElement('p'); summary.className='date-time-summary'; summary.setAttribute('aria-live','polite');
    group.append(dateLabel,timeLabel,summary); original.after(group); original.type='hidden';
    if(mainLabel) mainLabel.htmlFor=day.id;
    // Existing form validators target the original value; keep their messages
    // on a visible, focusable input after progressive enhancement.
    const setValidity = original.setCustomValidity.bind(original);
    original.setCustomValidity = message => { setValidity(message); day.setCustomValidity(message); };
    const describe = () => {
      if (!day.value || !time.value) { summary.textContent='Selecciona fecha y hora.'; return; }
      const value = new Date(day.value+'T'+time.value+':00Z');
      summary.textContent = new Intl.DateTimeFormat('es-CR',{weekday:'long',day:'numeric',month:'long',year:'numeric',hour:'2-digit',minute:'2-digit',hourCycle:'h23',timeZone:'UTC'}).format(value) + ' · Hora del negocio';
    };
    const update = event => {
      const seconds = event.target===day && original.value.slice(16) ? original.value.slice(16) : ':00';
      original.value = day.value && time.value ? day.value+'T'+time.value+seconds : '';
      original.dispatchEvent(new Event('input',{bubbles:true})); original.dispatchEvent(new Event('change',{bubbles:true}));
      describe();
    };
    day.addEventListener('input',update); time.addEventListener('input',update);
    const syncVisibility = () => { day.disabled=time.disabled=!!group.closest('[hidden]'); };
    new MutationObserver(syncVisibility).observe(parent,{attributes:true,attributeFilter:['hidden']});
    syncVisibility(); describe();
  });
})();
