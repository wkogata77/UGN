import React from 'react';
import { Crown, Flag, UserRound, Users, Truck } from 'lucide-react';
import { countMen } from '../game/model.js';

export function CommandStrip({ model, openOrganization }) {
  const s = model.state,
    battle = s.mode === 'battle';
  const units = s.battle?.units.filter((u) => u.side === 'player') || s.units;
  return (
    <section className="command-strip" aria-label="Chain of command">
      <button
        className={`general-select ${s.selectedCommander === s.general.id ? 'selected' : ''}`}
        aria-label="Select army general (G)"
        onClick={() =>
          battle ? model.selectCommander(s.general.id) : openOrganization()
        }
      >
        <Crown size={22} strokeWidth={1.3} />
        <span>
          <strong>{s.general.name}</strong>
          <small>ARMY COMMAND</small>
        </span>
      </button>
      <div className="corps-selectors">
        {s.corps.map((corps, index) => {
          const own = units.filter((u) => u.corpsId === corps.id);
          const active =
            own.some((u) => s.selected.includes(u.id)) &&
            s.selected.every((id) => own.some((u) => u.id === id));
          return (
            <div
              className={`corps-selector ${active ? 'selected' : ''}`}
              key={corps.id}
              style={{ '--corps-color': corps.color }}
            >
              <button
                className="corps-select"
                aria-label={`Select ${corps.name} (${index ? 'W' : 'Q'})`}
                onClick={() => model.selectCorps(corps.id)}
              >
                <Flag size={16} strokeWidth={1.4} />
                <span>
                  <strong>
                    {corps.name}{' '}
                    <b>{own.filter((u) => !u.parentId).length} / 4</b>
                  </strong>
                  <small>{corps.commander}</small>
                </span>
                <span className="corps-men">
                  {countMen(own).toLocaleString()}
                  <small>MEN</small>
                </span>
              </button>
              <button
                className={`corps-officer icon-button ${s.selectedCommander === corps.commanderId ? 'active' : ''}`}
                aria-label={`Select ${corps.name} commander`}
                data-tip={`${corps.commander} · ${corps.specialty}`}
                onClick={() =>
                  battle
                    ? model.selectCommander(corps.commanderId)
                    : openOrganization()
                }
              >
                <UserRound size={16} />
              </button>
            </div>
          );
        })}
      </div>
      {battle && (
        <button
          className={`icon-button supply-select ${s.selectedSupply ? 'active' : ''}`}
          aria-label="Select supply train"
          data-tip="Supply train"
          onClick={() => model.selectSupply()}
        >
          <Truck size={19} />
        </button>
      )}
      <button
        className="organization-button icon-button"
        aria-label="Army organization"
        data-tip="Army organization"
        disabled={battle}
        onClick={openOrganization}
      >
        <Users size={17} />
      </button>
    </section>
  );
}
