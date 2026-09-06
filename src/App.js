import React, { useMemo, useState } from "react";
import "./App.css";

const OMDB = "https://www.omdbapi.com/?apikey=cf20b56c";

const MOVIES = [
  "Rio 2","The Road to El Dorado","Encanto","Coco","About Time","Crazy Rich Asians","The Proposal","10 Things I Hate About You","Anyone But You","The Holiday","Mamma Mia!","La La Land","The Greatest Showman","Barbie","The Devil Wears Prada","Legally Blonde","Mean Girls","Game Night","Palm Springs","Knives Out","Glass Onion","Ocean's Eleven","Catch Me If You Can","Now You See Me","The Prestige","Inception","Interstellar","Arrival","The Martian","Dune","Dune: Part Two","Everything Everywhere All at Once","The Matrix","Edge of Tomorrow","Mad Max: Fury Road","Top Gun: Maverick","Mission: Impossible - Fallout","John Wick","The Batman","Spider-Man: Into the Spider-Verse","Spider-Man: Across the Spider-Verse","Black Panther","Guardians of the Galaxy","Free Guy","Jumanji: Welcome to the Jungle","Pirates of the Caribbean: The Curse of the Black Pearl","The Lord of the Rings: The Fellowship of the Ring","Harry Potter and the Sorcerer's Stone","Stardust","The Princess Bride","Paddington 2","The Parent Trap","Ratatouille","Up","Moana","Tangled","Zootopia","Shrek 2","Puss in Boots: The Last Wish","The Mitchells vs. the Machines","Soul","Inside Out","Inside Out 2","The Pursuit of Happyness","The Shawshank Redemption","Good Will Hunting","Little Women","The Notebook","Me Before You","A Star Is Born","Ford v Ferrari","Moneyball","The Social Network","Prisoners","Gone Girl","A Quiet Place","Get Out","The Conjuring","Scream","Nope","Parasite","Train to Busan","The Intouchables","The Grand Budapest Hotel","Chef","The Intern","Hidden Figures","The Secret Life of Walter Mitty","The Truman Show","Eternal Sunshine of the Spotless Mind"
];

const SERIES = [
  "Ted Lasso","Brooklyn Nine-Nine","The Good Place","Schitt's Creek","Modern Family","Abbott Elementary","Only Murders in the Building","The Bear","Succession","The White Lotus","Bridgerton","Queen Charlotte: A Bridgerton Story","Nobody Wants This","Heartstopper","Normal People","One Day","Outlander","Gilmore Girls","Friends","New Girl","How I Met Your Mother","Sex Education","Stranger Things","Dark","Black Mirror","Severance","Silo","Foundation","The Last of Us","Fallout","The Mandalorian","Andor","Game of Thrones","House of the Dragon","The Witcher","The Rings of Power","Wednesday","The Sandman","Arcane","Avatar: The Last Airbender","Blue Eye Samurai","The Office","Parks and Recreation","Community","Derry Girls","Fleabag","The Queen's Gambit","Peaky Blinders","Breaking Bad","Better Call Saul","Ozark","Money Heist","Lupin","Sherlock","Mindhunter","True Detective","The Night Agent","Reacher","Slow Horses","The Boys","Invincible","Chernobyl","Band of Brothers","The Crown","Downton Abbey","Anne with an E","A Series of Unfortunate Events","Cobra Kai","Outer Banks","The Summer I Turned Pretty","Never Have I Ever","Beef","Baby Reindeer","Shogun"
];

const GENRES = ["Comedy","Romance","Action","Thriller","Mystery","Crime","Sci-Fi","Fantasy","Adventure","Drama","Horror","Animation","Family","Musical","History"];

const QUESTIONS = [
  { key:"type", title:"Movie or series?", sub:"Start with the size of commitment you actually want tonight.", options:[
    ["movie","🎬","Movie","One complete story"],["series","📺","Series","Something I can keep watching"] ] },
  { key:"mood", title:"How are you feeling?", sub:"Pick the vibe you want the screen to give back to you.", options:[
    ["happy","😊","Happy & light","Good energy only"],["funny","😂","I need a laugh","Comedy first"],["cozy","🕯️","Cozy","Warm and easy"],["romantic","💘","Romantic","Chemistry please"],["adrenaline","⚡","Excited","Keep me hooked"],["emotional","🥹","Emotional","I want to feel something"],["adventure","🗺️","Adventurous","Take me somewhere else"],["mindbending","🧠","Mind-bending","Make me think"],["dark","🌑","Dark & moody","I can handle heavy"] ] },
  { key:"genres", title:"Which genres sound good?", sub:"Pick up to five. We’ll blend them instead of forcing one box.", multi:true },
  { key:"intensity", title:"How much energy do you have?", sub:"This helps avoid recommending something exhausting when you want easy watching.", options:[
    ["light","☁️","Light","Low-stress"],["balanced","🌙","Balanced","Some stakes"],["intense","🔥","Intense","Hit me hard"] ] },
  { key:"pace", title:"What pace do you want?", sub:"Slow burn, balanced, or hook-me-now?", options:[
    ["slow","🫖","Slow-burn","Atmosphere + characters"],["balanced","🎞️","Balanced","A bit of both"],["fast","🚀","Fast-paced","Keep it moving"] ] },
  { key:"era", title:"How old can it be?", sub:"Sometimes the perfect watch is not the newest one.", options:[
    ["any","🪩","Any era","Best match wins"],["classic","📼","Before 2000","Older classics welcome"],["2000s","💿","2000–2009","DVD-era favourites"],["2010s","📱","2010–2019","Modern favourites"],["recent","✨","2020+","Keep it recent"] ] },
  { key:"company", title:"Who are you watching with?", sub:"The right solo pick and the right date-night pick are not always the same.", options:[
    ["solo","🎧","Just me","No compromise"],["date","💞","Date night","Chemistry + conversation"],["friends","🍿","Friends","Easy group choice"],["family","🛋️","Family","Broad appeal"] ] },
  { key:"runtime", title:"How much time do you want to give it?", sub:"For series, think episode length. For movies, total runtime.", options:[
    ["short","⏱️","Keep it short","Under about 100 minutes / short episodes"],["normal","⌛","Normal length","No strong preference"],["long","🌌","I have time","Longer is fine"] ] },
  { key:"familiarity", title:"Safe choice or surprise me?", sub:"Tell me how adventurous the recommendation itself should be.", options:[
    ["popular","⭐","Popular favourites","Something proven"],["mix","🎯","A good mix","Known + surprising"],["hidden","💎","Hidden gems","Less obvious please"] ] },
  { key:"avoid", title:"Anything you want to avoid?", sub:"Last filter before we search.", options:[
    ["none","✅","No restrictions","Anything goes"],["horror","🫣","No horror","Nothing scary"],["dark","🌤️","Nothing too dark","Keep it lighter"],["sad","🥲","No heartbreak","Avoid heavy sadness"] ] }
];

const moodGenres = {
  happy:["Comedy","Family","Animation","Musical"], funny:["Comedy"], cozy:["Comedy","Family","Romance"],
  romantic:["Romance","Comedy","Drama"], adrenaline:["Action","Thriller","Adventure"], emotional:["Drama","Romance"],
  adventure:["Adventure","Fantasy","Action"], mindbending:["Sci-Fi","Mystery","Thriller"], dark:["Crime","Thriller","Horror","Mystery"]
};

const wikipediaSearch = async (query) => {
  const url = new URL("https://en.wikipedia.org/w/api.php");
  url.search = new URLSearchParams({action:"query",list:"search",srsearch:query,srlimit:"12",format:"json",origin:"*"});
  const r = await fetch(url);
  if (!r.ok) return [];
  const j = await r.json();
  return (j.query?.search || []).map(x => x.title.replace(/\s*\([^)]*film\)$/i, "").replace(/\s*\([^)]*TV series\)$/i, ""));
};

const getDetails = async (title, type) => {
  try {
    const r = await fetch(`${OMDB}&t=${encodeURIComponent(title)}&type=${type === "movie" ? "movie" : "series"}&plot=short`);
    const j = await r.json();
    return j.Response === "True" ? j : null;
  } catch { return null; }
};

const chunkedDetails = async (titles, type, limit=48) => {
  const out = [];
  const uniq = [...new Set(titles.map(x => x.trim()).filter(Boolean))].slice(0, limit);
  for (let i=0;i<uniq.length;i+=8) {
    const batch = await Promise.all(uniq.slice(i,i+8).map(t => getDetails(t,type)));
    out.push(...batch.filter(Boolean));
  }
  return out;
};

const parseYear = y => Number(String(y || "").match(/\d{4}/)?.[0] || 0);
const parseRuntime = r => Number(String(r || "").match(/\d+/)?.[0] || 0);

function scoreItem(item, a) {
  const genres = String(item.Genre || "").split(",").map(x => x.trim());
  const plot = String(item.Plot || "").toLowerCase();
  let score = 40;
  const reasons = [];
  const matches = genres.filter(g => a.genres.includes(g));
  if (matches.length) { score += matches.length * 11; reasons.push(matches.slice(0,2).join(" + ")); }
  const moodHits = (moodGenres[a.mood] || []).filter(g => genres.includes(g));
  if (moodHits.length) { score += Math.min(18,moodHits.length*7); reasons.push(`${a.mood} vibe`); }
  if (a.mood === "mindbending" && /(time|mystery|reality|dream|future|parallel|identity)/.test(plot)) score += 6;
  if (a.mood === "emotional" && /(family|love|loss|life|relationship)/.test(plot)) score += 5;
  const year = parseYear(item.Year);
  if (a.era === "classic") score += year && year < 2000 ? 10 : -5;
  if (a.era === "2000s") score += year>=2000 && year<=2009 ? 10 : -3;
  if (a.era === "2010s") score += year>=2010 && year<=2019 ? 10 : -3;
  if (a.era === "recent") score += year>=2020 ? 10 : -4;
  if (a.company === "date" && genres.some(g => ["Romance","Comedy"].includes(g))) { score+=7; reasons.push("date-night friendly"); }
  if (a.company === "friends" && genres.some(g => ["Comedy","Action","Thriller","Adventure"].includes(g))) score+=5;
  if (a.company === "family" && genres.some(g => ["Family","Animation","Adventure","Comedy"].includes(g))) { score+=9; reasons.push("family-friendly style"); }
  if (a.intensity === "light" && genres.some(g => ["Horror","Thriller","Crime"].includes(g))) score-=10;
  if (a.intensity === "intense" && genres.some(g => ["Thriller","Crime","Horror","Action","Drama"].includes(g))) score+=7;
  if (a.pace === "fast" && genres.some(g => ["Action","Thriller","Comedy","Adventure"].includes(g))) score+=5;
  if (a.pace === "slow" && genres.some(g => ["Drama","Mystery","Romance"].includes(g))) score+=4;
  const runtime = parseRuntime(item.Runtime);
  if (a.type === "movie" && a.runtime === "short" && runtime && runtime <= 105) score+=7;
  if (a.type === "movie" && a.runtime === "long" && runtime >= 135) score+=5;
  if (a.avoid === "horror" && genres.includes("Horror")) score-=40;
  if (a.avoid === "dark" && genres.some(g => ["Horror","Crime","Thriller"].includes(g))) score-=18;
  if (a.avoid === "sad" && /(death|loss|grief|tragedy|terminal|widow)/.test(plot)) score-=18;
  const rating = Number(item.imdbRating);
  if (Number.isFinite(rating)) score += Math.max(0,(rating-6)*4);
  if (a.familiarity === "popular" && Number(String(item.imdbVotes||"").replace(/,/g,"")) > 100000) score+=5;
  return { score, reason: reasons.slice(0,3).join(" • ") || "Strong overall match" };
}

function App() {
  const [step,setStep] = useState(0);
  const [answers,setAnswers] = useState({type:null,mood:null,genres:[],intensity:null,pace:null,era:null,company:null,runtime:null,familiarity:null,avoid:null});
  const [loading,setLoading] = useState(false);
  const [status,setStatus] = useState("");
  const [results,setResults] = useState([]);
  const [sort,setSort] = useState("match");
  const [saved,setSaved] = useState(() => new Set(JSON.parse(localStorage.getItem("tonightSaved") || "[]")));
  const [pick,setPick] = useState(null);

  const q = QUESTIONS[step];
  const canContinue = q.multi ? answers.genres.length > 0 : Boolean(answers[q.key]);

  const select = (value) => {
    if (q.multi) {
      setAnswers(a => ({...a,genres:a.genres.includes(value)?a.genres.filter(x=>x!==value):(a.genres.length<5?[...a.genres,value]:a.genres)}));
    } else setAnswers(a => ({...a,[q.key]:value}));
  };

  const search = async () => {
    setLoading(true); setStatus("Reading your taste profile…"); setResults([]);
    const typeWord = answers.type === "movie" ? "films" : "television series";
    let liveTitles = [];
    try {
      setStatus("Searching the web for fresh candidates…");
      const queries = [
        ...answers.genres.slice(0,3).map(g => `${g} ${typeWord}`),
        `${answers.mood} ${typeWord}`,
        answers.era === "recent" ? `2020s ${typeWord}` : null
      ].filter(Boolean);
      const found = await Promise.all(queries.map(wikipediaSearch));
      liveTitles = found.flat();
    } catch { liveTitles = []; }
    setStatus("Checking titles, posters, genres and ratings…");
    const fallback = answers.type === "movie" ? MOVIES : SERIES;
    let details = await chunkedDetails([...liveTitles,...fallback],answers.type,58);
    if (details.length < 30) {
      const more = fallback.filter(t => !details.some(d => d.Title.toLowerCase()===t.toLowerCase()));
      details = [...details,...await chunkedDetails(more,answers.type,70-details.length)];
    }
    const ranked = details.map(x => ({...x,...scoreItem(x,answers)})).sort((a,b)=>b.score-a.score);
    const max = ranked[0]?.score || 100, min = ranked[ranked.length-1]?.score || 0;
    const normalized = ranked.map(x => ({...x,match:Math.max(61,Math.min(98,Math.round(68 + ((x.score-min)/(Math.max(1,max-min)))*30))) })).slice(0,36);
    setResults(normalized); setStatus(liveTitles.length ? `Live web search found ${liveTitles.length} candidate titles before matching.` : "Live search was unavailable, so the curated fallback was used.");
    setLoading(false);
  };

  const displayed = useMemo(() => {
    const arr=[...results];
    if(sort==="newest") arr.sort((a,b)=>parseYear(b.Year)-parseYear(a.Year));
    if(sort==="rating") arr.sort((a,b)=>Number(b.imdbRating||0)-Number(a.imdbRating||0));
    if(sort==="shuffle") arr.sort(()=>Math.random()-.5);
    return arr;
  },[results,sort]);

  const toggleSave = (title) => {
    const next = new Set(saved); next.has(title)?next.delete(title):next.add(title); setSaved(next); localStorage.setItem("tonightSaved",JSON.stringify([...next]));
  };

  const restart = () => { setStep(0); setResults([]); setPick(null); setAnswers({type:null,mood:null,genres:[],intensity:null,pace:null,era:null,company:null,runtime:null,familiarity:null,avoid:null}); };

  if (loading) return <main className="page"><header className="top"><div className="brand"><span>▶</span> tonight.</div></header><section className="loadingCard"><div className="spinner"/><p className="kicker">SEARCHING THE WEB</p><h1>Building your watchlist…</h1><p>{status}</p></section></main>;

  if (results.length) return <main className="page">
    <header className="top"><div className="brand"><span>▶</span> tonight.</div><button className="ghost" onClick={restart}>Start over</button></header>
    <section className="resultsHead"><div><p className="kicker">YOUR WATCHLIST</p><h1>{results.length} {answers.type === "movie" ? "movies" : "series"} for tonight</h1><p>Built around <b>{answers.mood}</b> with {answers.genres.slice(0,3).join(", ")}.</p></div><select value={sort} onChange={e=>setSort(e.target.value)}><option value="match">Best match</option><option value="rating">IMDb rating</option><option value="newest">Newest</option><option value="shuffle">Shuffle</option></select></section>
    <div className="chips"><span>{answers.type === "movie" ? "🎬 Movie" : "📺 Series"}</span><span>💭 {answers.mood}</span>{answers.genres.slice(0,3).map(g=><span key={g}>{g}</span>)}<span>⚡ {answers.intensity}</span></div>
    <p className="webStatus">🌐 {status}</p>
    <section className="grid">{displayed.map((item,i)=><article className="titleCard" key={item.imdbID}>
      <div className="poster">{item.Poster && item.Poster!=="N/A" ? <img src={item.Poster} alt={`${item.Title} poster`}/> : <div className="noPoster">{item.Title.slice(0,2).toUpperCase()}</div>}<div className="match">{item.match}%</div></div>
      <div className="cardBody"><p className="rank">MATCH {String(i+1).padStart(2,"0")}</p><h2>{item.Title}</h2><p className="meta">{item.Year} • {item.Genre} • ⭐ {item.imdbRating}</p><p className="reason">{item.reason}</p><div className="cardActions"><button onClick={()=>toggleSave(item.Title)}>{saved.has(item.Title)?"♥ Saved":"♡ Save"}</button><a href={`https://www.google.com/search?q=${encodeURIComponent("where to watch "+item.Title+" South Africa")}`} target="_blank" rel="noreferrer">Where to watch ↗</a></div></div>
    </article>)}</section>
    <section className="picker"><div><p className="kicker">STILL STUCK?</p><h2>Stop scrolling. Let me choose.</h2></div><button className="primary" onClick={()=>setPick(displayed[Math.floor(Math.random()*Math.min(10,displayed.length))])}>Pick one for me ✨</button></section>
    {pick && <div className="modal" onClick={()=>setPick(null)}><div className="modalCard" onClick={e=>e.stopPropagation()}><p className="kicker">TONIGHT'S PICK</p><h2>{pick.Title}</h2><p>{pick.Plot}</p><p className="meta">{pick.Year} • {pick.Genre} • ⭐ {pick.imdbRating}</p><div className="modalButtons"><button className="ghost" onClick={()=>setPick(displayed[Math.floor(Math.random()*Math.min(10,displayed.length))])}>Pick another</button><button className="primary" onClick={()=>setPick(null)}>That’s the one 🍿</button></div></div></div>}
  </main>;

  return <main className="page"><header className="top"><div className="brand"><span>▶</span> tonight.</div><div className="pill">live discovery</div></header>
    <section className="hero"><p className="kicker">NO MORE ENDLESS SCROLLING</p><h1>What should we watch?</h1><p>Answer ten quick questions. Then I’ll search the web, check real movie data and build at least 30 matches around your mood.</p></section>
    <section className="quizCard"><div className="progress"><div style={{width:`${((step+1)/QUESTIONS.length)*100}%`}}/></div><div className="counter">{step+1} / {QUESTIONS.length}</div><p className="kicker">QUESTION {step+1}</p><h2>{q.title}</h2><p className="sub">{q.sub}</p>
      {q.multi ? <div className="genreGrid">{GENRES.map(g=><button key={g} className={answers.genres.includes(g)?"choice selected":"choice"} onClick={()=>select(g)}>{g}</button>)}</div> : <div className="choices">{q.options.map(([value,emoji,label,small])=><button key={value} className={answers[q.key]===value?"choice selected":"choice"} onClick={()=>select(value)}><span>{emoji}</span><div><strong>{label}</strong><small>{small}</small></div></button>)}</div>}
      <div className="nav"><button className="ghost" disabled={step===0} onClick={()=>setStep(s=>Math.max(0,s-1))}>← Back</button><button className="primary" disabled={!canContinue} onClick={()=>step===QUESTIONS.length-1?search():setStep(s=>s+1)}>{step===QUESTIONS.length-1?"Find my picks ✨":"Continue →"}</button></div>
    </section>
  </main>;
}

export default App;
